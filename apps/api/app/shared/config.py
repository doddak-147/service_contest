import os
from dataclasses import dataclass

DEFAULT_CORS_ORIGINS = (
    "http://localhost:8081",
    "http://localhost:19006",
)
VALID_STOCK_DATA_PROVIDERS = frozenset({"fake", "naver"})


@dataclass(frozen=True, slots=True)
class Settings:
    app_env: str
    cors_origins: tuple[str, ...]
    stock_data_provider: str = "fake"

    def __post_init__(self) -> None:
        normalized_provider = self.stock_data_provider.strip().lower()
        if normalized_provider not in VALID_STOCK_DATA_PROVIDERS:
            allowed = ", ".join(sorted(VALID_STOCK_DATA_PROVIDERS))
            raise ValueError(f"STOCK_DATA_PROVIDER must be one of: {allowed}")
        object.__setattr__(self, "stock_data_provider", normalized_provider)


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
    app_env = os.getenv("APP_ENV", "development").strip() or "development"
    provider = (
        os.getenv(
            "STOCK_DATA_PROVIDER",
            "fake" if app_env == "test" else "naver",
        )
        .strip()
        .lower()
    )
    return Settings(
        app_env=app_env,
        cors_origins=_parse_origins(os.getenv("CORS_ORIGINS")),
        stock_data_provider=provider,
    )
