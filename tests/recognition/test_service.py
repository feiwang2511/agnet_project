"""Unit tests for the recognition service."""

import base64

import pytest

from app.recognition.models import (
    ErrorResponse,
    ProviderRecognitionResult,
    RecognizeRequest,
    RecognizeResponse,
)
from app.recognition.provider import (
    FakeRecognitionProvider,
    InvalidModelOutput,
    RecognitionProviderUnavailable,
)
from app.recognition.service import recognize


# --- Test helpers ---

# Minimal valid JPEG (FF D8 FF)
VALID_JPEG_BYTES = b"\xff\xd8\xff\xe0" + b"\x00" * 100
VALID_JPEG_B64 = base64.b64encode(VALID_JPEG_BYTES).decode()

# Minimal valid PNG (89 50 4E 47)
VALID_PNG_BYTES = b"\x89PNG\r\n\x1a\n" + b"\x00" * 100
VALID_PNG_B64 = base64.b64encode(VALID_PNG_BYTES).decode()

# Not an image
NOT_IMAGE_BYTES = b"this is not an image"
NOT_IMAGE_B64 = base64.b64encode(NOT_IMAGE_BYTES).decode()


def _make_provider_result(**overrides) -> ProviderRecognitionResult:
    defaults = {
        "question_text": "求解 x + 2 = 5",
        "answer": "x = 3",
        "knowledge_points": ["一元一次方程"],
        "confidence": 0.85,
        "raw_model_output_id": "test_output_001",
    }
    defaults.update(overrides)
    return ProviderRecognitionResult(**defaults)


# --- AC-001: Valid image calls provider ---


def test_valid_jpeg_calls_provider():
    provider = FakeRecognitionProvider(result=_make_provider_result())
    req = RecognizeRequest(image=VALID_JPEG_B64, subject="math", grade="grade_7")
    result = recognize(req, provider)
    assert provider.called
    assert isinstance(result, RecognizeResponse)


def test_valid_png_calls_provider():
    provider = FakeRecognitionProvider(result=_make_provider_result())
    req = RecognizeRequest(image=VALID_PNG_B64)
    result = recognize(req, provider)
    assert provider.called
    assert isinstance(result, RecognizeResponse)


# --- AC-002: Invalid images do NOT call provider ---


def test_empty_image_does_not_call_provider():
    provider = FakeRecognitionProvider(result=_make_provider_result())
    req = RecognizeRequest(image="")
    result = recognize(req, provider)
    assert not provider.called
    assert isinstance(result, ErrorResponse)
    assert result.error.code == "invalid_image"


def test_invalid_base64_does_not_call_provider():
    provider = FakeRecognitionProvider(result=_make_provider_result())
    req = RecognizeRequest(image="not-valid-base64!!!")
    result = recognize(req, provider)
    assert not provider.called
    assert isinstance(result, ErrorResponse)
    assert result.error.code == "invalid_image"


def test_non_image_format_does_not_call_provider():
    provider = FakeRecognitionProvider(result=_make_provider_result())
    req = RecognizeRequest(image=NOT_IMAGE_B64)
    result = recognize(req, provider)
    assert not provider.called
    assert isinstance(result, ErrorResponse)
    assert result.error.code == "invalid_image"


def test_oversized_image_does_not_call_provider():
    big_jpeg = b"\xff\xd8\xff\xe0" + b"\x00" * (10 * 1024 * 1024 + 1)
    big_b64 = base64.b64encode(big_jpeg).decode()
    provider = FakeRecognitionProvider(result=_make_provider_result())
    req = RecognizeRequest(image=big_b64)
    result = recognize(req, provider)
    assert not provider.called
    assert isinstance(result, ErrorResponse)
    assert result.error.code == "invalid_image"


# --- AC-003: Successful response has complete schema ---


def test_success_response_has_all_fields():
    provider = FakeRecognitionProvider(result=_make_provider_result())
    req = RecognizeRequest(image=VALID_JPEG_B64)
    result = recognize(req, provider)
    assert isinstance(result, RecognizeResponse)
    assert result.question_text == "求解 x + 2 = 5"
    assert result.answer == "x = 3"
    assert result.knowledge_points == ["一元一次方程"]
    assert result.confidence == 0.85
    assert result.status == "confirmed"
    assert result.raw_model_output_id == "test_output_001"


# --- AC-004: Low confidence -> needs_confirmation ---


def test_confidence_below_threshold_needs_confirmation():
    provider = FakeRecognitionProvider(
        result=_make_provider_result(confidence=0.74)
    )
    req = RecognizeRequest(image=VALID_JPEG_B64)
    result = recognize(req, provider)
    assert isinstance(result, RecognizeResponse)
    assert result.status == "needs_confirmation"


def test_confidence_at_threshold_confirmed():
    provider = FakeRecognitionProvider(
        result=_make_provider_result(confidence=0.75)
    )
    req = RecognizeRequest(image=VALID_JPEG_B64)
    result = recognize(req, provider)
    assert isinstance(result, RecognizeResponse)
    assert result.status == "confirmed"


# --- AC-005: High confidence but bad schema -> error ---


def test_high_confidence_missing_question_text_returns_error():
    provider = FakeRecognitionProvider(
        result=_make_provider_result(confidence=0.9, question_text="")
    )
    req = RecognizeRequest(image=VALID_JPEG_B64)
    result = recognize(req, provider)
    assert isinstance(result, ErrorResponse)
    assert result.error.code == "invalid_model_output"


def test_confidence_out_of_range_returns_error():
    provider = FakeRecognitionProvider(
        result=_make_provider_result(confidence=1.2)
    )
    req = RecognizeRequest(image=VALID_JPEG_B64)
    result = recognize(req, provider)
    assert isinstance(result, ErrorResponse)
    assert result.error.code == "invalid_model_output"


def test_negative_confidence_returns_error():
    provider = FakeRecognitionProvider(
        result=_make_provider_result(confidence=-0.1)
    )
    req = RecognizeRequest(image=VALID_JPEG_B64)
    result = recognize(req, provider)
    assert isinstance(result, ErrorResponse)
    assert result.error.code == "invalid_model_output"


# --- AC-006: Provider exceptions -> structured errors ---


def test_provider_unavailable_returns_error():
    provider = FakeRecognitionProvider(
        error=RecognitionProviderUnavailable("timeout")
    )
    req = RecognizeRequest(image=VALID_JPEG_B64)
    result = recognize(req, provider)
    assert isinstance(result, ErrorResponse)
    assert result.error.code == "recognition_unavailable"


def test_invalid_model_output_from_provider_returns_error():
    provider = FakeRecognitionProvider(
        error=InvalidModelOutput("bad json")
    )
    req = RecognizeRequest(image=VALID_JPEG_B64)
    result = recognize(req, provider)
    assert isinstance(result, ErrorResponse)
    assert result.error.code == "invalid_model_output"


# --- AC-007: subject/grade passed to provider ---


def test_subject_and_grade_passed_to_provider():
    provider = FakeRecognitionProvider(result=_make_provider_result())
    req = RecognizeRequest(image=VALID_JPEG_B64, subject="physics", grade="grade_9")
    recognize(req, provider)
    assert provider.last_subject == "physics"
    assert provider.last_grade == "grade_9"
