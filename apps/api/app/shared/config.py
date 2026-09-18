import os
from dataclasses import dataclass, field

# Flutter Android requests are not subject to browser CORS. Browser origins must
# therefore be opted into explicitly instead of retaining the old Expo defaults.
DEFAULT_CORS_ORIGINS: tuple[str, ...] = ()
VALID_STOCK_DATA_PROVIDERS = frozenset({"fake", "naver"})
VALID_LLM_PROVIDERS = frozenset({"template", "openai_compatible"})


@dataclass(frozen=True, slots=True)
class Settings:
    app_env: str
    cors_origins: tuple[str, ...]
    stock_data_provider: str = "fake"
    llm_provider: str = "template"
    llm_api_url: str | None = None
    llm_api_key: str | None = field(default=None, repr=False)
    llm_model: str | None = None

    def __post_init__(self) -> None:
        normalized_env = self.app_env.strip().lower() or "development"
        normalized_provider = self.stock_data_provider.strip().lower()
        normalized_llm_provider = self.llm_provider.strip().lower()
        normalized_llm_url = (
            self.llm_api_url.strip() if self.llm_api_url else None
        )
        normalized_llm_key = (
            self.llm_api_key.strip() if self.llm_api_key else None
        )
        normalized_llm_model = (
            self.llm_model.strip() if self.llm_model else None
        )
        if normalized_provider not in VALID_STOCK_DATA_PROVIDERS:
            allowed = ", ".join(sorted(VALID_STOCK_DATA_PROVIDERS))
            raise ValueError(f"STOCK_DATA_PROVIDER must be one of: {allowed}")
        if normalized_llm_provider not in VALID_LLM_PROVIDERS:
            allowed = ", ".join(sorted(VALID_LLM_PROVIDERS))
            raise ValueError(f"LLM_PROVIDER must be one of: {allowed}")
        if normalized_llm_provider == "openai_compatible" and not all(
            (normalized_llm_url, normalized_llm_key, normalized_llm_model)
        ):
            raise ValueError(
                "LLM_API_URL, LLM_API_KEY, and LLM_MODEL are required "
                "for openai_compatible"
            )
        object.__setattr__(self, "app_env", normalized_env)
        object.__setattr__(self, "stock_data_provider", normalized_provider)
        object.__setattr__(self, "llm_provider", normalized_llm_provider)
        object.__setattr__(self, "llm_api_url", normalized_llm_url)
        object.__setattr__(self, "llm_api_key", normalized_llm_key)
        object.__setattr__(self, "llm_model", normalized_llm_model)


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
    app_env = os.getenv("APP_ENV", "development")
    normalized_app_env = app_env.strip().lower() or "development"
    provider = (
        os.getenv(
            "STOCK_DATA_PROVIDER",
            "fake" if normalized_app_env == "test" else "naver",
        )
        .strip()
        .lower()
    )
    return Settings(
        app_env=app_env,
        cors_origins=_parse_origins(os.getenv("CORS_ORIGINS")),
        stock_data_provider=provider,
        llm_provider=os.getenv("LLM_PROVIDER", "template"),
        llm_api_url=os.getenv("LLM_API_URL") or None,
        llm_api_key=os.getenv("LLM_API_KEY") or None,
        llm_model=os.getenv("LLM_MODEL") or None,
    )
