import secrets
from typing import Annotated

from fastapi import APIRouter, Depends, Request, Response

from app.features.foundation.risk_quiz import (
    TOPICS,
    QuizRequest,
    QuizResult,
    build_quiz,
)
from app.integrations.llm.base import LlmUnavailableError
from app.integrations.llm.quiz_wordings import QuizWordingAdapter, UnsafeQuizWording

router = APIRouter(prefix="/api/v1/risk-learning", tags=["foundation"])


def get_quiz_adapter(request: Request) -> QuizWordingAdapter | None:
    settings = request.app.state.settings
    if settings.llm_provider != "openai_compatible":
        return None
    if not hasattr(request.app.state, "quiz_adapter"):
        request.app.state.quiz_adapter = QuizWordingAdapter(
            api_url=settings.llm_api_url,
            api_key=settings.llm_api_key,
            model=settings.llm_model,
        )
    return request.app.state.quiz_adapter


@router.post("/quizzes", response_model=QuizResult)
async def create_quiz(
    payload: QuizRequest,
    response: Response,
    adapter: Annotated[QuizWordingAdapter | None, Depends(get_quiz_adapter)],
) -> QuizResult:
    response.headers["Cache-Control"] = "no-store"
    questions = build_quiz(
        payload.seed if payload.seed is not None else secrets.randbits(31)
    )
    if adapter is None:
        return QuizResult(
            source="template", fallback_reason="not_configured", questions=questions
        )
    try:
        wordings = await adapter.generate(TOPICS)
        return QuizResult(
            source="llm",
            questions=[
                q.model_copy(
                    update={
                        "title": wordings[q.topic].title,
                        "intro": wordings[q.topic].intro,
                    }
                )
                for q in questions
            ],
        )
    except LlmUnavailableError:
        reason = "provider_unavailable"
    except UnsafeQuizWording:
        reason = "safety_rejected"
    return QuizResult(source="template", fallback_reason=reason, questions=questions)
