"""Core recognition service: validation, provider call, schema check, gating."""

import base64
import logging
from typing import Union

from app.recognition.models import (
    CONFIDENCE_THRESHOLD,
    MAX_IMAGE_SIZE_BYTES,
    ErrorDetail,
    ErrorResponse,
    RecognizeRequest,
    RecognizeResponse,
    generate_request_id,
)
from app.recognition.provider import (
    InvalidModelOutput,
    RecognitionProvider,
    RecognitionProviderUnavailable,
)

logger = logging.getLogger(__name__)

# JPEG: FF D8 FF, PNG: 89 50 4E 47
_JPEG_MAGIC = b"\xff\xd8\xff"
_PNG_MAGIC = b"\x89PNG"


def _detect_format(data: bytes) -> str | None:
    if data[:3] == _JPEG_MAGIC:
        return "jpeg"
    if data[:4] == _PNG_MAGIC:
        return "png"
    return None


def recognize(
    request: RecognizeRequest,
    provider: RecognitionProvider,
) -> Union[RecognizeResponse, ErrorResponse]:
    request_id = generate_request_id()

    # --- Image validation (before provider call) ---
    if not request.image:
        return ErrorResponse(
            error=ErrorDetail(
                code="invalid_image",
                message="Image must be a non-empty JPEG or PNG under 10 MB.",
                request_id=request_id,
            )
        )

    try:
        image_bytes = base64.b64decode(request.image, validate=True)
    except Exception:
        return ErrorResponse(
            error=ErrorDetail(
                code="invalid_image",
                message="Image must be a non-empty JPEG or PNG under 10 MB.",
                request_id=request_id,
            )
        )

    if len(image_bytes) == 0:
        return ErrorResponse(
            error=ErrorDetail(
                code="invalid_image",
                message="Image must be a non-empty JPEG or PNG under 10 MB.",
                request_id=request_id,
            )
        )

    fmt = _detect_format(image_bytes)
    if fmt is None:
        return ErrorResponse(
            error=ErrorDetail(
                code="invalid_image",
                message="Image must be a non-empty JPEG or PNG under 10 MB.",
                request_id=request_id,
            )
        )

    if len(image_bytes) > MAX_IMAGE_SIZE_BYTES:
        return ErrorResponse(
            error=ErrorDetail(
                code="invalid_image",
                message="Image must be a non-empty JPEG or PNG under 10 MB.",
                request_id=request_id,
            )
        )

    # --- Provider call ---
    try:
        result = provider.recognize(
            image_bytes=image_bytes,
            subject=request.subject,
            grade=request.grade,
            request_id=request_id,
        )
    except RecognitionProviderUnavailable:
        logger.warning("Provider unavailable, request_id=%s", request_id)
        return ErrorResponse(
            error=ErrorDetail(
                code="recognition_unavailable",
                message="Recognition service is temporarily unavailable.",
                request_id=request_id,
            )
        )
    except InvalidModelOutput:
        logger.warning("Invalid model output, request_id=%s", request_id)
        return ErrorResponse(
            error=ErrorDetail(
                code="invalid_model_output",
                message="Model returned an invalid or incomplete response.",
                request_id=request_id,
            )
        )

    # --- Schema validation on provider result ---
    if not result.question_text or not isinstance(result.question_text, str):
        logger.warning("Missing question_text, request_id=%s", request_id)
        return ErrorResponse(
            error=ErrorDetail(
                code="invalid_model_output",
                message="Model returned an invalid or incomplete response.",
                request_id=request_id,
            )
        )

    if not isinstance(result.confidence, (int, float)):
        logger.warning("Invalid confidence type, request_id=%s", request_id)
        return ErrorResponse(
            error=ErrorDetail(
                code="invalid_model_output",
                message="Model returned an invalid or incomplete response.",
                request_id=request_id,
            )
        )

    if result.confidence < 0 or result.confidence > 1:
        logger.warning("Confidence out of range, request_id=%s", request_id)
        return ErrorResponse(
            error=ErrorDetail(
                code="invalid_model_output",
                message="Model returned an invalid or incomplete response.",
                request_id=request_id,
            )
        )

    if not isinstance(result.knowledge_points, list):
        logger.warning("Invalid knowledge_points type, request_id=%s", request_id)
        return ErrorResponse(
            error=ErrorDetail(
                code="invalid_model_output",
                message="Model returned an invalid or incomplete response.",
                request_id=request_id,
            )
        )

    # --- Confidence gating ---
    if result.confidence < CONFIDENCE_THRESHOLD:
        status = "needs_confirmation"
    else:
        status = "confirmed"

    return RecognizeResponse(
        question_text=result.question_text,
        answer=result.answer,
        knowledge_points=result.knowledge_points,
        confidence=result.confidence,
        status=status,
        raw_model_output_id=result.raw_model_output_id,
    )
