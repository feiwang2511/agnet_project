"""Recognition provider boundary."""

from abc import ABC, abstractmethod
from typing import Optional

from app.recognition.models import ProviderRecognitionResult


class RecognitionProviderUnavailable(Exception):
    """Raised when the provider is unreachable (timeout, throttle, auth failure)."""
    pass


class InvalidModelOutput(Exception):
    """Raised when the provider returns unparseable or schema-violating content."""
    pass


class RecognitionProvider(ABC):
    @abstractmethod
    def recognize(
        self,
        image_bytes: bytes,
        subject: Optional[str],
        grade: Optional[str],
        request_id: str,
    ) -> ProviderRecognitionResult:
        ...


class FakeRecognitionProvider(RecognitionProvider):
    """Test double that returns controlled results."""

    def __init__(self, result: Optional[ProviderRecognitionResult] = None, error: Optional[Exception] = None):
        self._result = result
        self._error = error
        self.called = False
        self.last_image_bytes: Optional[bytes] = None
        self.last_subject: Optional[str] = None
        self.last_grade: Optional[str] = None

    def recognize(
        self,
        image_bytes: bytes,
        subject: Optional[str],
        grade: Optional[str],
        request_id: str,
    ) -> ProviderRecognitionResult:
        self.called = True
        self.last_image_bytes = image_bytes
        self.last_subject = subject
        self.last_grade = grade
        if self._error:
            raise self._error
        if self._result is None:
            raise InvalidModelOutput("No result configured in fake provider")
        return self._result
