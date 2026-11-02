import asyncio
import json
import re
from decimal import ROUND_HALF_UP, Decimal

import httpx
import pytest
from fastapi.testclient import TestClient

from app.features.foundation.quiz_router import get_quiz_adapter
from app.features.foundation.risk_quiz import TOPICS, build_quiz
from app.integrations.llm.base import LlmUnavailableError
from app.integrations.llm.quiz_wordings import (
    QuizWordingAdapter,
    UnsafeQuizWording,
    validate_wordings,
)
from app.main import create_app
from app.shared.config import Settings


def wordings() -> dict:
    return {
        "items": [
            {
                "topic": topic,
                "title": "가상 사례를 살펴볼까요?",
                "intro": "가상 인물의 메모를 읽고 주어진 조건을 확인해 봅니다.",
            }
            for topic in TOPICS
        ]
    }


def test_rounds_have_five_distinct_topics_and_varied_facts() -> None:
    assert build_quiz(42) == build_quiz(42)
    seen = set()
    prompts = set()
    for seed in range(80):
        questions = build_quiz(seed)
        assert len(questions) == len({q.topic for q in questions}) == 5
        for q in questions:
            assert len(q.options) == len(set(q.options)) == 3
            assert 0 <= q.correct_index < 3
            seen.add(q.topic)
            prompts.add(q.prompt)
    assert seen == set(TOPICS)
    assert len(prompts) > 60


def test_every_generated_answer_matches_independent_arithmetic() -> None:
    for seed in range(80):
        for q in build_quiz(seed):
            numbers = [
                Decimal(n.replace(",", ""))
                for n in re.findall(r"-?\d[\d,]*(?:\.\d+)?", q.prompt)
            ]
            answer = q.options[q.correct_index]
            actual = Decimal(
                re.search(r"-?\d[\d,]*(?:\.\d+)?", answer)[0].replace(",", "")
            )
            match q.topic:
                case "recovery":
                    expected = numbers[0] / (100 - numbers[0]) * 100
                case "fx":
                    expected = numbers[0]
                    assert ("감소" in answer) == ("하락" in q.prompt)
                case "compound_fx":
                    p, fx = numbers
                    expected = ((100 + p) * (100 + fx) / 100) - 100
                case "interest":
                    principal, rate, months = numbers
                    expected = principal * rate / 1200 * months
                case "cash_flow":
                    income, expenses, debt, interest = numbers
                    expected = income - expenses - debt - interest
                case "valuation":
                    expected = numbers[0]
                case "rate_shock":
                    principal, before, after, _ = numbers

                    def rounded(
                        rate: Decimal, principal: Decimal = principal
                    ) -> Decimal:
                        return (principal * rate / 1200).quantize(
                            Decimal(1), rounding=ROUND_HALF_UP
                        )

                    expected = rounded(after) - rounded(before)
                case "drawdown":
                    peak, trough = numbers
                    expected = (peak - trough) / peak * 100
            assert actual == expected.quantize(Decimal("0.01"))


@pytest.mark.parametrize(
    "text",
    [
        "정답은 10%입니다",
        "투자를 추천합니다",
        "오백만 원",
        "매수해도 됩니다",
        "<script>실행</script>",
    ],
)
def test_model_cannot_add_numbers_advice_or_markup(text: str) -> None:
    body = wordings()
    body["items"][0]["intro"] = text
    with pytest.raises(UnsafeQuizWording):
        validate_wordings(json.dumps(body), set(TOPICS))


def test_model_cannot_replace_options_or_omit_topics() -> None:
    body = wordings()
    body["items"][0]["correct_index"] = 0
    with pytest.raises(UnsafeQuizWording):
        validate_wordings(json.dumps(body), set(TOPICS))
    body = wordings()
    body["items"][0] = body["items"][1]
    with pytest.raises(UnsafeQuizWording):
        validate_wordings(json.dumps(body), set(TOPICS))


def test_adapter_sends_topics_only_and_reuses_wordings() -> None:
    calls = []

    def handler(request: httpx.Request) -> httpx.Response:
        calls.append(json.loads(request.content))
        assert request.headers["authorization"] == "Bearer synthetic-key"
        return httpx.Response(
            200,
            json={
                "choices": [
                    {"message": {"content": json.dumps(wordings(), ensure_ascii=False)}}
                ]
            },
        )

    async def run() -> None:
        async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
            adapter = QuizWordingAdapter(
                api_url="https://example.test/chat",
                api_key="synthetic-key",
                model="qa",
                client=client,
            )
            await adapter.generate(TOPICS)
            await adapter.generate(TOPICS)

    asyncio.run(run())
    assert len(calls) == 1
    assert json.loads(calls[0]["messages"][1]["content"]) == TOPICS
    assert "financial_profile" not in json.dumps(calls)
    assert "synthetic-key" not in json.dumps(calls)


@pytest.mark.parametrize(
    "failure,reason",
    [
        (None, None),
        (LlmUnavailableError, "provider_unavailable"),
        (UnsafeQuizWording, "safety_rejected"),
    ],
)
def test_endpoint_keeps_verified_questions_on_llm_failure(failure, reason) -> None:
    class Adapter:
        async def generate(self, topics):
            if failure:
                raise failure()
            return validate_wordings(json.dumps(wordings()), set(topics))

    app = create_app(Settings(app_env="test", cors_origins=()))
    app.dependency_overrides[get_quiz_adapter] = lambda: Adapter()
    with TestClient(app) as client:
        response = client.post("/api/v1/risk-learning/quizzes", json={"seed": 42})
        assert response.status_code == 200
        assert response.headers["cache-control"] == "no-store"
        body = response.json()
        assert body["source"] == ("llm" if reason is None else "template")
        assert body["fallback_reason"] == reason
        expected = build_quiz(42)
        for actual, q in zip(body["questions"], expected, strict=True):
            for field in [
                "prompt",
                "options",
                "correct_index",
                "formula",
                "explanation",
            ]:
                assert actual[field] == getattr(q, field)


def test_template_mode_and_request_limits() -> None:
    with TestClient(create_app(Settings(app_env="test", cors_origins=()))) as client:
        body = client.post("/api/v1/risk-learning/quizzes", json={}).json()
        assert body["fallback_reason"] == "not_configured"
        assert len(body["questions"]) == 5
        for payload in [
            {"seed": True},
            {"seed": -1},
            {"seed": 2147483648},
            {"financial_profile": {}},
            {"count": 100},
        ]:
            assert (
                client.post("/api/v1/risk-learning/quizzes", json=payload).status_code
                == 422
            )
