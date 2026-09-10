from fastapi.testclient import TestClient

from app.main import create_app
from app.shared.config import Settings

TEST_ORIGIN = "http://localhost:8081"


def make_client() -> TestClient:
    app = create_app(Settings(app_env="test", cors_origins=(TEST_ORIGIN,)))
    return TestClient(app)


def test_health_returns_ok_and_request_id() -> None:
    with make_client() as client:
        response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
    assert response.headers["X-Request-ID"]


def test_health_allows_configured_cors_origin() -> None:
    with make_client() as client:
        response = client.options(
            "/health",
            headers={
                "Origin": TEST_ORIGIN,
                "Access-Control-Request-Method": "GET",
            },
        )

    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == TEST_ORIGIN


def test_not_found_uses_common_error_response() -> None:
    with make_client() as client:
        response = client.get("/missing")

    body = response.json()
    assert response.status_code == 404
    assert body["error"]["code"] == "VALIDATION_ERROR"
    assert body["error"]["field_errors"] == []
    assert body["error"]["request_id"] == response.headers["X-Request-ID"]


def test_unhandled_exception_uses_common_error_response() -> None:
    app = create_app(Settings(app_env="test", cors_origins=(TEST_ORIGIN,)))

    @app.get("/test-error", include_in_schema=False)
    async def raise_test_error() -> None:
        raise RuntimeError("sensitive internal detail")

    with TestClient(app, raise_server_exceptions=False) as client:
        response = client.get("/test-error")

    body = response.json()
    assert response.status_code == 500
    assert body["error"]["code"] == "INTERNAL_ERROR"
    assert "sensitive internal detail" not in response.text
    assert body["error"]["request_id"] == response.headers["X-Request-ID"]
