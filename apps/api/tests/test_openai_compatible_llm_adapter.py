import asyncio
import json

import httpx
import pytest

from app.integrations.llm.base import LlmUnavailableError
from app.integrations.llm.openai_compatible import (
    OpenAICompatibleExplanationAdapter,
)


def test_adapter_sends_minimal_payload_and_reads_json_summary() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.headers["Authorization"] == "Bearer test-key"
        body = json.loads(request.content)
        assert body["model"] == "test-model"
        user_payload = json.loads(body["messages"][1]["content"])
        assert user_payload == {"scenario_key": "down_20"}
        return httpx.Response(
            200,
            json={
                "choices": [
                    {
                        "message": {
                            "content": json.dumps(
                                {
                                    "summary": (
                                        "손실은 {{investment_loss_krw}}입니다."
                                    )
                                },
                                ensure_ascii=False,
                            )
                        }
                    }
                ]
            },
        )

    async def run() -> None:
        async with httpx.AsyncClient(
            transport=httpx.MockTransport(handler)
        ) as client:
            adapter = OpenAICompatibleExplanationAdapter(
                api_url="https://llm.example.test/v1/chat/completions",
                api_key="test-key",
                model="test-model",
                client=client,
            )
            draft = await adapter.generate({"scenario_key": "down_20"})

        assert draft.summary == "손실은 {{investment_loss_krw}}입니다."

    asyncio.run(run())


def test_adapter_hides_provider_failures() -> None:
    def handler(_request: httpx.Request) -> httpx.Response:
        return httpx.Response(500, text="secret provider detail")

    async def run() -> None:
        async with httpx.AsyncClient(
            transport=httpx.MockTransport(handler)
        ) as client:
            adapter = OpenAICompatibleExplanationAdapter(
                api_url="https://llm.example.test/v1/chat/completions",
                api_key="test-key",
                model="test-model",
                client=client,
            )
            with pytest.raises(LlmUnavailableError) as exc_info:
                await adapter.generate({"scenario_key": "down_20"})

        assert "secret provider detail" not in str(exc_info.value)

    asyncio.run(run())
