from abc import ABC, abstractmethod
from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class ExplanationDraft:
    summary: str


class LlmUnavailableError(Exception):
    """Raised when the optional explanation provider cannot return a draft."""


class ExplanationAdapter(ABC):
    @abstractmethod
    async def generate(self, payload: dict[str, object]) -> ExplanationDraft:
        """Generate wording only; financial values remain owned by the server."""
