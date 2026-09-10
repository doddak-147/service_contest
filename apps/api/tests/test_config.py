from app.shared.config import DEFAULT_CORS_ORIGINS, load_settings


def test_load_settings_uses_defaults(monkeypatch) -> None:
    monkeypatch.delenv("APP_ENV", raising=False)
    monkeypatch.delenv("CORS_ORIGINS", raising=False)

    settings = load_settings()

    assert settings.app_env == "development"
    assert settings.cors_origins == DEFAULT_CORS_ORIGINS


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
