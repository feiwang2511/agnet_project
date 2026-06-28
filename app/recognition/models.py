"""Schema models for the recognition service."""

import uuid
from dataclasses import dataclass, field
from typing import Optional


CONFIDENCE_THRESHOLD = 0.75
MAX_IMAGE_SIZE_BYTES = 10 * 1024 * 1024  # 10 MB
SUPPORTED_FORMATS = ("jpeg", "png")


@dataclass
class RecognizeRequest:
    image: str  # base64-encoded
    subject: Optional[str] = None
    grade: Optional[str] = None


@dataclass
class ProviderRecognitionResult:
    question_text: str
    answer: Optional[str]
    knowledge_points: list[str]
    confidence: float
    raw_model_output_id: str


@dataclass
class RecognizeResponse:
    question_text: str
    answer: Optional[str]
    knowledge_points: list[str]
    confidence: float
    status: str  # "confirmed" | "needs_confirmation"
    raw_model_output_id: str


@dataclass
class ErrorDetail:
    code: str
    message: str
    request_id: str


@dataclass
class ErrorResponse:
    error: ErrorDetail


def generate_request_id() -> str:
    return f"req_{uuid.uuid4().hex[:16]}"
