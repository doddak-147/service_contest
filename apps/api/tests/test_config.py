import pytest

from app.shared.config import DEFAULT_CORS_ORIGINS, Settings, load_settings


def test_load_settings_uses_defaults(monkeypatch) -> None:
    monkeypatch.delenv("APP_ENV", raising=False)
    monkeypatch.delenv("CORS_ORIGINS", raising=False)
    monkeypatch.delenv("STOCK_DATA_PROVIDER", raising=False)

    settings = load_settings()

    assert settings.app_env == "development"
    assert settings.cors_origins == DEFAULT_CORS_ORIGINS
    assert settings.stock_data_provider == "naver"


def test_load_settings_parses_unique_origins(monkeypatch) -> None:
    monkeypatch.setenv("APP_ENV", "test")
    monkeypatch.setenv(
        "CORS_ORIGINS",
        "https://example.com/, https://example.com, http://localhost:8081",
    )

    settings = load_settings()

    assert settings.app_env == "test"
    assert settings.cors_origins == (
        "https://example.com",
        "http://localhost:8081",
    )
    assert settings.stock_data_provider == "fake"


def test_settings_normalizes_stock_provider() -> None:
    settings = Settings(
        app_env="development",
        cors_origins=DEFAULT_CORS_ORIGINS,
        stock_data_provider=" NAVER ",
    )

    assert settings.stock_data_provider == "naver"


def test_settings_rejects_unknown_stock_provider() -> None:
    with pytest.raises(ValueError, match="STOCK_DATA_PROVIDER"):
        Settings(
            app_env="production",
            cors_origins=DEFAULT_CORS_ORIGINS,
            stock_data_provider="naverr",
        )
