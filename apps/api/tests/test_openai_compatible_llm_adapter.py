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
        assert set(body) == {
            "model",
            "reasoning_effort",
            "response_format",
            "messages",
        }
        assert body["model"] == "test-model"
        assert body["reasoning_effort"] == "none"
        assert body["response_format"]["type"] == "json_schema"
        schema = body["response_format"]["json_schema"]
        assert schema["strict"] is True
        assert schema["schema"]["required"] == ["summary"]
        assert schema["schema"]["additionalProperties"] is False
        user_payload = json.loads(body["messages"][1]["content"])
        assert user_payload == {"scenario_key": "down_20"}
        return httpx.Response(
            200,
            json={
                "choices": [
                    {
                        "message": {
                            "content": json.dumps(
                                {"summary": ("손실은 {{investment_loss_krw}}입니다.")},
                                ensure_ascii=False,
                            )
                        }
                    }
                ]
            },
        )

    async def run() -> None:
        async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
            adapter = OpenAICompatibleExplanationAdapter(
                api_url="https://llm.example.test/v1/chat/completions",
                api_key="test-key",
                model="test-model",
                client=client,
            )
            draft = await adapter.generate({"scenario_key": "down_20"})

        assert draft.summary == "손실은 {{investment_loss_krw}}입니다."

    asyncio.run(run())


def test_adapter_hides_provider_failures(caplog: pytest.LogCaptureFixture) -> None:
    def handler(_request: httpx.Request) -> httpx.Response:
        return httpx.Response(
            429,
            json={
                "error": {
                    "type": "insufficient_quota",
                    "code": "credit_balance_exhausted",
                    "param": "model",
                    "message": (
                        "Invalid request using sk-test-secret-123456789 "
                        "for amount 2000000"
                    ),
                }
            },
        )

    async def run() -> None:
        async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
            adapter = OpenAICompatibleExplanationAdapter(
                api_url="https://llm.example.test/v1/chat/completions",
                api_key="test-key",
                model="test-model",
                client=client,
            )
            with pytest.raises(LlmUnavailableError) as exc_info:
                await adapter.generate({"scenario_key": "down_20"})

        assert "sk-test-secret-123456789" not in str(exc_info.value)
        assert "sk-test-secret-123456789" not in caplog.text
        assert "2000000" not in caplog.text
        assert "status=429" in caplog.text
        assert (
            "endpoint=https://llm.example.test/v1/chat/completions" in caplog.text
        )
        assert "content_type=application/json" in caplog.text
        assert "server=unknown" in caplog.text
        assert "request_id=missing" in caplog.text
        assert (
            "auth_shape=length:8,starts_sk:False,whitespace:False,"
            "bearer_prefix:False,wrapped:False" in caplog.text
        )
        assert "type=insufficient_quota" in caplog.text
        assert "code=credit_balance_exhausted" in caplog.text
        assert "param=model" in caplog.text
        assert "message=Invalid request using [redacted-secret]" in caplog.text
        assert "for amount [redacted-number]" in caplog.text
        assert "body_shape=object(keys=error;" in caplog.text

    asyncio.run(run())


def test_adapter_logs_sanitized_plain_text_error(
    caplog: pytest.LogCaptureFixture,
) -> None:
    def handler(_request: httpx.Request) -> httpx.Response:
        return httpx.Response(400, text="Unsupported parameter: reasoning_effort")

    async def run() -> None:
        async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
            adapter = OpenAICompatibleExplanationAdapter(
                api_url="https://llm.example.test/v1/chat/completions",
                api_key="test-key",
                model="test-model",
                client=client,
            )
            with pytest.raises(LlmUnavailableError):
                await adapter.generate({"scenario_key": "down_20"})

        assert "status=400" in caplog.text
        assert "message=Unsupported parameter: reasoning_effort" in caplog.text

    asyncio.run(run())


def test_adapter_logs_validation_detail_without_input_values(
    caplog: pytest.LogCaptureFixture,
) -> None:
    def handler(_request: httpx.Request) -> httpx.Response:
        return httpx.Response(
            400,
            json={
                "detail": [
                    {
                        "type": "missing",
                        "loc": ["body", "input"],
                        "msg": "Field required",
                        "input": {"private_value": 3000000},
                    }
                ]
            },
        )

    async def run() -> None:
        async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
            adapter = OpenAICompatibleExplanationAdapter(
                api_url="https://llm.example.test/v1/responses?key=secret",
                api_key="test-key",
                model="test-model",
                client=client,
            )
            with pytest.raises(LlmUnavailableError):
                await adapter.generate({"scenario_key": "down_20"})

        assert "endpoint=https://llm.example.test/v1/responses" in caplog.text
        assert "type=missing" in caplog.text
        assert "location=['body', 'input']" in caplog.text
        assert "message=Field required" in caplog.text
        assert "private_value" not in caplog.text
        assert "3000000" not in caplog.text
        assert "body_shape=object(keys=detail;error_kind=NoneType)" in caplog.text

    asyncio.run(run())
