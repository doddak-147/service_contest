import os
from dataclasses import dataclass

DEFAULT_CORS_ORIGINS = (
    "http://localhost:8081",
    "http://localhost:19006",
)


@dataclass(frozen=True, slots=True)
class Settings:
    app_env: str
    cors_origins: tuple[str, ...]


def _parse_origins(raw_origins: str | None) -> tuple[str, ...]:
    if raw_origins is None:
        return DEFAULT_CORS_ORIGINS

    origins = tuple(
        dict.fromkeys(
            origin.strip().rstrip("/")
            for origin in raw_origins.split(",")
            if origin.strip()
        )
    )
    return origins or DEFAULT_CORS_ORIGINS


def load_settings() -> Settings:
    return Settings(
        app_env=os.getenv("APP_ENV", "development").strip() or "development",
        cors_origins=_parse_origins(os.getenv("CORS_ORIGINS")),
    )
