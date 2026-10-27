import json
import logging
import re
from typing import Any
from urllib.parse import urlsplit

import httpx

from app.integrations.llm.base import (
    ExplanationAdapter,
    ExplanationDraft,
    LlmUnavailableError,
)

logger = logging.getLogger(__name__)

_SECRET_PATTERNS = (
    re.compile(r"\bsk-[A-Za-z0-9_-]{8,}\b"),
    re.compile(r"\bBearer\s+\S+", re.IGNORECASE),
)
_LONG_NUMBER_PATTERN = re.compile(r"(?<![\w.-])\d{3,}(?:[.,]\d+)*(?![\w.-])")
_WHITESPACE_PATTERN = re.compile(r"\s+")
_MAX_ERROR_MESSAGE_LENGTH = 300

SUMMARY_RESPONSE_FORMAT = {
    "type": "json_schema",
    "json_schema": {
        "name": "financial_risk_explanation",
        "strict": True,
        "schema": {
            "type": "object",
            "properties": {"summary": {"type": "string"}},
            "required": ["summary"],
            "additionalProperties": False,
        },
    },
}

EXPLANATION_PLACEHOLDERS = (
    "assumed_return_rate",
    "investment_loss_krw",
    "loss_to_equity_ratio",
    "loss_to_emergency_fund_ratio",
    "loss_to_monthly_fixed_expenses",
    "net_investment_equity_krw",
    "estimated_monthly_interest_krw",
    "market_max_drawdown_rate",
)

SYSTEM_PROMPT = """당신은 금융위험 계산 결과를 쉬운 한국어로 설명한다.
투자 추천, 매수·매도 판단, 투자 가능 여부, 미래 가격 예측을 절대 작성하지 않는다.
입력에는 실제 숫자가 없으며, 사용 가능한 자리표시자 이름만 있다.
summary에는 반드시 사용 가능한 자리표시자를 포함한다.
숫자와 수량 단위를 직접 쓰지 않는다.
실제 금액·비율은 서버가 자리표시자를 나중에 바꾼다. 새 숫자나 계산을 만들지 않는다.
자리표시자의 의미를 바꾸지 않는다. 특히 손실 비율의 분모를 바꾸지 않는다.
{{loss_to_equity_ratio}} 앞에는 반드시 '자기자본 대비'를 쓴다.
{{loss_to_emergency_fund_ratio}} 앞에는 반드시 '비상자금 대비'를 쓴다.
{{loss_to_monthly_fixed_expenses}} 앞에는 반드시 '월 고정지출'을 쓴다.
{{net_investment_equity_krw}} 앞에는 반드시 '손실 후 순투자지분'을 쓴다.
{{estimated_monthly_interest_krw}} 앞에는 반드시 '월 이자'를 쓴다.
{{market_max_drawdown_rate}} 앞에는 반드시 '과거 최대낙폭'을 쓴다.
값이 다른 기준보다 크거나 작은지 비교하지 않는다.
올바른 예: 가격 변화를 가정하면 예상 손실은 {{investment_loss_krw}}입니다.
두 문장 이내의 summary만 가진 JSON object를 반환한다."""


def _prompt_context(payload: dict[str, object]) -> dict[str, object]:
    rate = payload.get("assumed_return_rate")
    scenario_key = payload.get("scenario_key")
    if scenario_key == "historical_mdd":
        scenario_type = "historical_decline"
    elif isinstance(rate, (int, float)) and rate > 0:
        scenario_type = "hypothetical_increase"
    elif isinstance(rate, (int, float)) and rate < 0:
        scenario_type = "hypothetical_decline"
    else:
        scenario_type = "hypothetical_flat"

    loss = payload.get("investment_loss_krw")
    equity = payload.get("net_investment_equity_krw")
    interest = payload.get("estimated_monthly_interest_krw")
    return {
        "scenario_type": scenario_type,
        "loss_exists": isinstance(loss, int) and loss > 0,
        "equity_exhausted": isinstance(equity, int) and equity < 0,
        "interest_applies": isinstance(interest, int) and interest > 0,
        "available_placeholders": [
            name for name in EXPLANATION_PLACEHOLDERS if payload.get(name) is not None
        ],
    }


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
            "response_format": SUMMARY_RESPONSE_FORMAT,
            "messages": [
                {"role": "system", "content": SYSTEM_PROMPT},
                {
                    "role": "user",
                    "content": json.dumps(_prompt_context(payload), ensure_ascii=False),
                },
            ],
        }
        try:
            if self._client is None:
                async with httpx.AsyncClient(
                    timeout=30.0,
                    trust_env=False,
                ) as client:
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
                    timeout=30.0,
                )
            response.raise_for_status()
            body: Any = response.json()
            content = body["choices"][0]["message"]["content"]
            parsed = json.loads(content)
            summary = parsed["summary"]
            if not isinstance(summary, str):
                raise TypeError
            return ExplanationDraft(summary=summary)
        except httpx.HTTPStatusError as exc:
            error_type, error_code, error_param, error_message, body_shape = (
                _provider_error_details(exc.response)
            )
            logger.warning(
                "LLM provider rejected the request: "
                "status=%s endpoint=%s content_type=%s "
                "server=%s request_id=%s auth_shape=%s "
                "type=%s code=%s param=%s message=%s body_shape=%s",
                exc.response.status_code,
                _safe_endpoint(self._api_url),
                exc.response.headers.get("content-type", "unknown"),
                exc.response.headers.get("server", "unknown"),
                "present"
                if exc.response.headers.get("x-request-id")
                else "missing",
                _describe_api_key(self._api_key),
                error_type,
                error_code,
                error_param,
                error_message,
                body_shape,
            )
            raise LlmUnavailableError from None
        except httpx.RequestError as exc:
            logger.warning(
                "LLM provider connection failed: error=%s",
                type(exc).__name__,
            )
            raise LlmUnavailableError from None
        except (KeyError, IndexError, TypeError, ValueError) as exc:
            logger.warning(
                "LLM provider returned an invalid response: error=%s",
                type(exc).__name__,
            )
            raise LlmUnavailableError from None


def _provider_error_details(
    response: httpx.Response,
) -> tuple[str, str, str, str, str]:
    try:
        body = response.json()
    except (json.JSONDecodeError, TypeError, ValueError):
        return (
            "unknown",
            "unknown",
            "unknown",
            _sanitize_error_message(response.text),
            "non-json",
        )

    if not isinstance(body, dict):
        return (
            "unknown",
            "unknown",
            "unknown",
            "non-object JSON response",
            type(body).__name__,
        )

    error = body.get("error")
    if not isinstance(error, dict):
        message = error if isinstance(error, str) else body.get("detail")
        if message is None:
            message = body.get("message")
        return (
            "unknown",
            "unknown",
            "unknown",
            _extract_error_message(message),
            _describe_error_body(body),
        )

    values = (error.get("type"), error.get("code"), error.get("param"))
    error_type, error_code, error_param = (
        _sanitize_error_field(value) for value in values
    )
    return (
        error_type,
        error_code,
        error_param,
        _extract_error_message(error.get("message")),
        _describe_error_body(body),
    )


def _safe_endpoint(api_url: str) -> str:
    parsed = urlsplit(api_url)
    if not parsed.scheme or not parsed.hostname:
        return "invalid-url"
    port = f":{parsed.port}" if parsed.port is not None else ""
    return f"{parsed.scheme}://{parsed.hostname}{port}{parsed.path}"


def _describe_api_key(api_key: str) -> str:
    has_whitespace = any(character.isspace() for character in api_key)
    starts_with_sk = api_key.startswith("sk-")
    has_bearer_prefix = api_key.lower().startswith("bearer ")
    wrapped = (
        len(api_key) >= 2
        and (api_key[0], api_key[-1])
        in {('"', '"'), ("'", "'"), ("<", ">")}
    )
    return (
        f"length:{len(api_key)},starts_sk:{starts_with_sk},"
        f"whitespace:{has_whitespace},bearer_prefix:{has_bearer_prefix},"
        f"wrapped:{wrapped}"
    )


def _describe_error_body(body: dict[str, object]) -> str:
    top_level_keys = ",".join(sorted(str(key) for key in body)) or "none"
    error = body.get("error")
    if isinstance(error, dict):
        error_keys = ",".join(sorted(str(key) for key in error)) or "none"
        return f"object(keys={top_level_keys};error_keys={error_keys})"
    return f"object(keys={top_level_keys};error_kind={type(error).__name__})"


def _extract_error_message(value: object) -> str:
    if isinstance(value, str):
        return _sanitize_error_message(value)
    if isinstance(value, list) and value:
        first = value[0]
        if isinstance(first, dict):
            message = first.get("msg") or first.get("message")
            error_type = first.get("type")
            location = first.get("loc")
            parts = [
                f"type={error_type}" if isinstance(error_type, str) else "",
                f"location={location}" if isinstance(location, list) else "",
                f"message={message}" if isinstance(message, str) else "",
            ]
            return _sanitize_error_message(" ".join(part for part in parts if part))
    if isinstance(value, dict):
        nested_message = value.get("msg") or value.get("message")
        if isinstance(nested_message, str):
            return _sanitize_error_message(nested_message)
    return "unavailable"


def _sanitize_error_field(value: object) -> str:
    if not isinstance(value, str) or not value:
        return "unknown"
    return _sanitize_error_message(value)


def _sanitize_error_message(value: object) -> str:
    if not isinstance(value, str) or not value:
        return "unavailable"

    sanitized = value
    for pattern in _SECRET_PATTERNS:
        sanitized = pattern.sub("[redacted-secret]", sanitized)
    sanitized = _LONG_NUMBER_PATTERN.sub("[redacted-number]", sanitized)
    sanitized = _WHITESPACE_PATTERN.sub(" ", sanitized).strip()
    return sanitized[:_MAX_ERROR_MESSAGE_LENGTH] or "unavailable"
