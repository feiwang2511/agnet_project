"""Security tests: no secrets or user data in logs/errors/fixtures."""

import base64
import logging
import re

import pytest

from app.recognition.models import ProviderRecognitionResult, RecognizeRequest
from app.recognition.provider import FakeRecognitionProvider, RecognitionProviderUnavailable
from app.recognition.service import recognize


VALID_JPEG_BYTES = b"\xff\xd8\xff\xe0" + b"\x00" * 100
VALID_JPEG_B64 = base64.b64encode(VALID_JPEG_BYTES).decode()

SECRET_PATTERNS = [
    r"AKIA[0-9A-Z]{16}",
    r"BEGIN (RSA|OPENSSH|EC) PRIVATE KEY",
    r"sk-[A-Za-z0-9_-]{20,}",
]


def test_error_message_does_not_contain_full_base64_image():
    """Error messages must not leak user image content."""
    big_image = b"\xff\xd8\xff\xe0" + b"\xab" * 500
    big_b64 = base64.b64encode(big_image).decode()
    provider = FakeRecognitionProvider(
        error=RecognitionProviderUnavailable("fail")
    )
    req = RecognizeRequest(image=big_b64)
    result = recognize(req, provider)
    error_text = result.error.message + result.error.request_id
    # Should not contain the full base64 string
    assert big_b64 not in error_text


def test_fixture_files_do_not_contain_secrets():
    """Test source files must not embed real secrets."""
    import pathlib

    test_dir = pathlib.Path(__file__).parent
    for f in test_dir.glob("*.py"):
        content = f.read_text()
        for pattern in SECRET_PATTERNS:
            matches = re.findall(pattern, content)
            assert not matches, f"Possible secret in {f.name}: {matches}"


def test_log_output_contains_only_request_id(caplog):
    """Logs should only contain request_id and error code, not image data."""
    provider = FakeRecognitionProvider(
        error=RecognitionProviderUnavailable("timeout")
    )
    req = RecognizeRequest(image=VALID_JPEG_B64)
    with caplog.at_level(logging.WARNING):
        recognize(req, provider)
    for record in caplog.records:
        assert VALID_JPEG_B64 not in record.getMessage()
        assert "request_id=" in record.getMessage() or "req_" in record.getMessage()
