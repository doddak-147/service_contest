import json
from typing import Any

import httpx

from app.integrations.llm.base import (
    ExplanationAdapter,
    ExplanationDraft,
    LlmUnavailableError,
)

SYSTEM_PROMPT = """당신은 금융위험 계산 결과를 쉬운 한국어로 설명한다.
투자 추천, 매수·매도 판단, 투자 가능 여부, 미래 가격 예측을 절대 작성하지 않는다.
입력 숫자를 직접 쓰거나 새로 계산하지 말고 아래 허용 자리표시자만 사용한다.
허용 자리표시자:
{{assumed_return_rate}}, {{investment_loss_krw}}, {{loss_to_equity_ratio}},
{{loss_to_emergency_fund_ratio}}, {{loss_to_monthly_fixed_expenses}},
{{net_investment_equity_krw}}, {{estimated_monthly_interest_krw}},
{{market_max_drawdown_rate}}.
두 문장 이내의 summary만 가진 JSON object를 반환한다."""


class OpenAICompatibleExplanationAdapter(ExplanationAdapter):
    def __init__(
        self,
        *,
        api_url: str,
        api_key: str,
        model: str,
        client: httpx.AsyncClient | None = None,
    ) -> None:
        self._api_url = api_url
        self._api_key = api_key
        self._model = model
        self._client = client

    async def generate(self, payload: dict[str, object]) -> ExplanationDraft:
        request_body = {
            "model": self._model,
            "messages": [
                {"role": "system", "content": SYSTEM_PROMPT},
                {
                    "role": "user",
                    "content": json.dumps(payload, ensure_ascii=False),
                },
            ],
        }
        try:
            if self._client is None:
                async with httpx.AsyncClient(timeout=10.0) as client:
                    response = await client.post(
                        self._api_url,
                        headers={"Authorization": f"Bearer {self._api_key}"},
                        json=request_body,
                    )
            else:
                response = await self._client.post(
                    self._api_url,
                    headers={"Authorization": f"Bearer {self._api_key}"},
                    json=request_body,
                    timeout=10.0,
                )
            response.raise_for_status()
            body: Any = response.json()
            content = body["choices"][0]["message"]["content"]
            parsed = json.loads(content)
            summary = parsed["summary"]
            if not isinstance(summary, str):
                raise TypeError
            return ExplanationDraft(summary=summary)
        except (httpx.HTTPError, KeyError, IndexError, TypeError, ValueError) as exc:
            raise LlmUnavailableError from exc
