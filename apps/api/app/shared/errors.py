from typing import Literal

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from starlette.exceptions import HTTPException as StarletteHTTPException

ErrorCode = Literal[
    "VALIDATION_ERROR",
    "INSTRUMENT_NOT_FOUND",
    "INSUFFICIENT_PRICE_DATA",
    "MARKET_DATA_UNAVAILABLE",
    "EXPLANATION_UNAVAILABLE",
    "INTERNAL_ERROR",
]


class FieldError(BaseModel):
    field: str
    reason: str


class ErrorDetail(BaseModel):
    code: ErrorCode
    message: str
    field_errors: list[FieldError]
    request_id: str


class ErrorResponse(BaseModel):
    error: ErrorDetail


def _request_id(request: Request) -> str:
    return str(request.state.request_id)


def _json_error(
    request: Request,
    *,
    status_code: int,
    code: ErrorCode,
    message: str,
    field_errors: list[FieldError] | None = None,
) -> JSONResponse:
    request_id = _request_id(request)
    response = ErrorResponse(
        error=ErrorDetail(
            code=code,
            message=message,
            field_errors=field_errors or [],
            request_id=request_id,
        )
    )
    return JSONResponse(
        status_code=status_code,
        content=response.model_dump(),
        headers={"X-Request-ID": request_id},
    )


def register_error_handlers(app: FastAPI) -> None:
    @app.exception_handler(RequestValidationError)
    async def validation_error_handler(
        request: Request, exc: RequestValidationError
    ) -> JSONResponse:
        field_errors = [
            FieldError(
                field=".".join(str(part) for part in error["loc"]),
                reason=str(error["type"]).upper(),
            )
            for error in exc.errors()
        ]
        return _json_error(
            request,
            status_code=422,
            code="VALIDATION_ERROR",
            message="입력값을 확인해 주세요.",
            field_errors=field_errors,
        )

    @app.exception_handler(StarletteHTTPException)
    async def http_error_handler(
        request: Request, exc: StarletteHTTPException
    ) -> JSONResponse:
        message = (
            "요청한 경로를 찾을 수 없습니다."
            if exc.status_code == 404
            else "요청을 처리할 수 없습니다."
        )
        return _json_error(
            request,
            status_code=exc.status_code,
            code="VALIDATION_ERROR",
            message=message,
        )

    @app.exception_handler(Exception)
    async def unhandled_error_handler(
        request: Request, _exc: Exception
    ) -> JSONResponse:
        return _json_error(
            request,
            status_code=500,
            code="INTERNAL_ERROR",
            message="서버에서 요청을 처리하지 못했습니다.",
        )
