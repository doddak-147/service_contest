"""LLM supplies optional framing only, never facts, options or answers."""

import asyncio
import json
import re
import time

import httpx
from pydantic import BaseModel, ConfigDict, Field, ValidationError

from app.integrations.llm.base import LlmUnavailableError


class UnsafeQuizWording(ValueError):
    pass


class Wording(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    topic: str
    title: str = Field(min_length=3, max_length=40)
    intro: str = Field(min_length=8, max_length=120)


class Wordings(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    items: list[Wording]


RESPONSE_SCHEMA = {
    "type": "object",
    "properties": {
        "items": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    name: {"type": "string"} for name in ("topic", "title", "intro")
                },
                "required": ["topic", "title", "intro"],
                "additionalProperties": False,
            },
        }
    },
    "required": ["items"],
    "additionalProperties": False,
}


_UNSAFE = re.compile(
    r"[\d０-９A-Za-z%{}<>=]|https?://"
    r"|(?:[영공일이삼사오육칠팔구십백천만억조한두세네다섯여섯반]+\s*(?:원|퍼센트|개월|달|배))"
    r"|매수|매도|추천|권장|보장|예측|정답|오답|확실|적합|안전한|위험한|레버리지.*좋|빚.*좋"
)
PROMPT = """가상 금융 개념 퀴즈의 제목과 짧은 도입 장면만 한국어로 작성한다.
숫자, 수량, 금액, 금리, 기간, 실제 인물, 실제 종목을 작성하지 않는다.
정답, 계산식, 선택지, 투자 행동 권고를 작성하지 않는다.
수치·전제·문제·정답은 서버가 별도로 작성한다.
새로운 금융 조건이나 인과관계를 추가하지 않는다.
도입은 가상 인물의 메모나 연습 기록을 살펴보는 중립적 장면이다.
주제마다 제목과 도입 문장을 서로 다르게 작성한다. 같은 문장을 반복하지 않는다.
질문의 답을 암시하지 않는다.
title과 intro에는 영문 알파벳이나 기호도 쓰지 않는다.
topic 식별자는 요청의 영문 값을 그대로 유지한다.
제목은 다양한 질문형 표현을 쓸 수 있다. 각 주제당 title과 intro를 작성한다.
요청된 topic을 한 번씩 포함한 items 배열의 JSON만 반환한다."""


def validate_wordings(content: str, topics: set[str]) -> dict[str, Wording]:
    try:
        result = Wordings.model_validate_json(content)
    except (ValidationError, ValueError) as exc:
        raise UnsafeQuizWording from exc
    if len(result.items) != len(topics) or {w.topic for w in result.items} != topics:
        raise UnsafeQuizWording
    for wording in result.items:
        if _UNSAFE.search(wording.title + " " + wording.intro):
            raise UnsafeQuizWording
    return {w.topic: w for w in result.items}


class QuizWordingAdapter:
    def __init__(
        self,
        *,
        api_url: str,
        api_key: str,
        model: str,
        client: httpx.AsyncClient | None = None,
    ) -> None:
        self._api_url, self._api_key, self._model = api_url, api_key, model
        self._client = client
        self._lock = asyncio.Lock()
        self._cached: dict[str, Wording] | None = None
        self._expires = 0.0

    async def generate(self, topics: dict[str, str]) -> dict[str, Wording]:
        async with self._lock:
            if self._cached is not None and time.monotonic() < self._expires:
                return self._cached
            request = {
                "model": self._model,
                "response_format": {
                    "type": "json_schema",
                    "json_schema": {
                        "name": "risk_quiz_wordings",
                        "strict": True,
                        "schema": RESPONSE_SCHEMA,
                    },
                },
                "messages": [
                    {"role": "system", "content": PROMPT},
                    {"role": "user", "content": json.dumps(topics, ensure_ascii=False)},
                ],
            }
            try:
                if self._client is None:
                    async with httpx.AsyncClient(timeout=20, trust_env=False) as client:
                        response = await client.post(
                            self._api_url,
                            headers={"Authorization": f"Bearer {self._api_key}"},
                            json=request,
                        )
                else:
                    response = await self._client.post(
                        self._api_url,
                        headers={"Authorization": f"Bearer {self._api_key}"},
                        json=request,
                        timeout=20,
                    )
                response.raise_for_status()
                content = response.json()["choices"][0]["message"]["content"]
                if not isinstance(content, str):
                    raise TypeError
            except (httpx.HTTPError, KeyError, IndexError, TypeError, ValueError):
                # Never log provider bodies, prompts, headers or credentials.
                raise LlmUnavailableError from None
            result = validate_wordings(content, set(topics))
            self._cached = result
            self._expires = time.monotonic() + 600
            return result
