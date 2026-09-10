from fastapi import APIRouter

from app.features.foundation.schemas import HealthResponse

router = APIRouter(tags=["foundation"])


@router.get("/health", response_model=HealthResponse)
async def get_health() -> HealthResponse:
    return HealthResponse()
