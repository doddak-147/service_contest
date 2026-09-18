from typing import Annotated

from fastapi import APIRouter, Depends, Request

from app.features.combined_report.explanation import (
    UnsafeExplanationError,
    build_llm_explanation,
    build_template_explanation,
)
from app.features.combined_report.schemas import (
    ExplanationInput,
    ExplanationResult,
)
from app.integrations.llm.base import ExplanationAdapter, LlmUnavailableError
from app.integrations.llm.openai_compatible import (
    OpenAICompatibleExplanationAdapter,
)

router = APIRouter(prefix="/api/v1/explanations", tags=["combined-report"])


def get_explanation_adapter(request: Request) -> ExplanationAdapter | None:
    settings = request.app.state.settings
    if settings.llm_provider == "template":
        return None
    if settings.llm_provider == "openai_compatible":
        return OpenAICompatibleExplanationAdapter(
            api_url=settings.llm_api_url,
            api_key=settings.llm_api_key,
            model=settings.llm_model,
        )
    raise RuntimeError("Unsupported LLM provider configuration")


@router.post("", response_model=ExplanationResult)
async def create_explanation(
    payload: ExplanationInput,
    adapter: Annotated[
        ExplanationAdapter | None, Depends(get_explanation_adapter)
    ],
) -> ExplanationResult:
    if adapter is None:
        return build_template_explanation(payload)

    try:
        draft = await adapter.generate(payload.model_dump())
        return build_llm_explanation(payload, draft)
    except (LlmUnavailableError, UnsafeExplanationError):
        return build_template_explanation(payload)
