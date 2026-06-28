"""Bedrock Claude provider implementation."""

import json
import logging
import uuid
from typing import Optional

import boto3
from botocore.exceptions import ClientError

from app.recognition.models import ProviderRecognitionResult
from app.recognition.provider import (
    InvalidModelOutput,
    RecognitionProvider,
    RecognitionProviderUnavailable,
)

logger = logging.getLogger(__name__)

BEDROCK_MODEL_ID = "us.anthropic.claude-sonnet-4-20250514-v1:0"
BEDROCK_REGION = "us-east-1"


class BedrockRecognitionProvider(RecognitionProvider):
    def __init__(self, region: str = BEDROCK_REGION, model_id: str = BEDROCK_MODEL_ID):
        self._region = region
        self._model_id = model_id
        self._client = boto3.client("bedrock-runtime", region_name=region)

    def recognize(
        self,
        image_bytes: bytes,
        subject: Optional[str],
        grade: Optional[str],
        request_id: str,
    ) -> ProviderRecognitionResult:
        import base64

        image_b64 = base64.b64encode(image_bytes).decode("utf-8")

        if image_bytes[:4] == b"\x89PNG":
            media_type = "image/png"
        else:
            media_type = "image/jpeg"

        context_parts = []
        if subject:
            context_parts.append(f"学科: {subject}")
        if grade:
            context_parts.append(f"年级: {grade}")
        context_hint = "。".join(context_parts) if context_parts else ""

        prompt_text = (
            "你是一个题目识别助手。请分析这张图片中的题目，返回严格 JSON 格式：\n"
            '{"question_text": "题目文本", "answer": "答案或null", '
            '"knowledge_points": ["知识点1", "知识点2"], "confidence": 0.85}\n'
            "要求：\n"
            "- question_text 必须是非空字符串\n"
            "- knowledge_points 必须是数组，无法识别时返回空数组\n"
            "- confidence 是你对识别结果可靠性的评分，范围 [0, 1]\n"
            "- 只输出 JSON，不要其他文字\n"
        )
        if context_hint:
            prompt_text += f"\n上下文: {context_hint}\n"

        body = {
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 2048,
            "messages": [
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "image",
                            "source": {
                                "type": "base64",
                                "media_type": media_type,
                                "data": image_b64,
                            },
                        },
                        {
                            "type": "text",
                            "text": prompt_text,
                        },
                    ],
                }
            ],
        }

        try:
            response = self._client.invoke_model(
                modelId=self._model_id,
                body=json.dumps(body),
                contentType="application/json",
                accept="application/json",
            )
        except ClientError as e:
            error_code = e.response.get("Error", {}).get("Code", "")
            logger.warning(
                "Bedrock API error, code=%s, request_id=%s",
                error_code,
                request_id,
            )
            raise RecognitionProviderUnavailable(
                f"Bedrock unavailable: {error_code}"
            ) from e
        except Exception as e:
            logger.warning("Bedrock call failed, request_id=%s", request_id)
            raise RecognitionProviderUnavailable(
                "Bedrock call failed"
            ) from e

        try:
            response_body = json.loads(response["body"].read())
            content_text = response_body["content"][0]["text"].strip()
            # Strip markdown code fences if present
            if content_text.startswith("```"):
                lines = content_text.split("\n")
                # Remove first line (```json) and last line (```)
                lines = [l for l in lines if not l.strip().startswith("```")]
                content_text = "\n".join(lines).strip()
            parsed = json.loads(content_text)
        except (json.JSONDecodeError, KeyError, IndexError, TypeError) as e:
            logger.warning("Cannot parse Bedrock response, request_id=%s", request_id)
            raise InvalidModelOutput("Unparseable model response") from e

        raw_model_output_id = f"bedrock_{uuid.uuid4().hex[:12]}"

        question_text = parsed.get("question_text")
        if not question_text or not isinstance(question_text, str):
            raise InvalidModelOutput("Missing or invalid question_text")

        confidence = parsed.get("confidence")
        if not isinstance(confidence, (int, float)) or confidence < 0 or confidence > 1:
            raise InvalidModelOutput("Invalid confidence value")

        knowledge_points = parsed.get("knowledge_points")
        if not isinstance(knowledge_points, list):
            raise InvalidModelOutput("Invalid knowledge_points")

        answer = parsed.get("answer")

        return ProviderRecognitionResult(
            question_text=question_text,
            answer=answer,
            knowledge_points=knowledge_points,
            confidence=float(confidence),
            raw_model_output_id=raw_model_output_id,
        )
