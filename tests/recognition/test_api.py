"""API-level tests for POST /recognize."""

import base64

import pytest
from fastapi.testclient import TestClient

from app.main import create_app
from app.recognition.models import ProviderRecognitionResult
from app.recognition.provider import (
    FakeRecognitionProvider,
    RecognitionProviderUnavailable,
)


VALID_JPEG_BYTES = b"\xff\xd8\xff\xe0" + b"\x00" * 100
VALID_JPEG_B64 = base64.b64encode(VALID_JPEG_BYTES).decode()


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


def _create_test_client(provider: FakeRecognitionProvider) -> TestClient:
    app = create_app(provider=provider)
    return TestClient(app)


def test_post_recognize_success():
    provider = FakeRecognitionProvider(result=_make_provider_result())
    client = _create_test_client(provider)
    resp = client.post("/recognize", json={"image": VALID_JPEG_B64, "subject": "math"})
    assert resp.status_code == 200
    data = resp.json()
    assert data["question_text"] == "求解 x + 2 = 5"
    assert data["confidence"] == 0.85
    assert data["status"] == "confirmed"
    assert "raw_model_output_id" in data


def test_post_recognize_invalid_image_returns_400():
    provider = FakeRecognitionProvider(result=_make_provider_result())
    client = _create_test_client(provider)
    resp = client.post("/recognize", json={"image": ""})
    assert resp.status_code == 400
    data = resp.json()
    assert data["error"]["code"] == "invalid_image"
    assert "request_id" in data["error"]


def test_post_recognize_provider_unavailable_returns_502():
    provider = FakeRecognitionProvider(
        error=RecognitionProviderUnavailable("timeout")
    )
    client = _create_test_client(provider)
    resp = client.post("/recognize", json={"image": VALID_JPEG_B64})
    assert resp.status_code == 502
    data = resp.json()
    assert data["error"]["code"] == "recognition_unavailable"


def test_response_does_not_contain_sdk_objects():
    provider = FakeRecognitionProvider(result=_make_provider_result())
    client = _create_test_client(provider)
    resp = client.post("/recognize", json={"image": VALID_JPEG_B64})
    data = resp.json()
    # No boto3/botocore-specific keys
    assert "ResponseMetadata" not in str(data)
    assert "HTTPStatusCode" not in str(data)
