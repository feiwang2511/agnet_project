"""FastAPI router for all API endpoints."""

import json
from decimal import Decimal
from typing import Optional

from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel

from app.recognition.models import ErrorResponse, RecognizeRequest, RecognizeResponse
from app.recognition.service import recognize as recognize_service
from app.recognition import db

router = APIRouter()


class _DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            if obj % 1 == 0:
                return int(obj)
            return float(obj)
        return super().default(obj)


def _json_response(content, status_code=200):
    return JSONResponse(
        status_code=status_code,
        content=json.loads(json.dumps(content, cls=_DecimalEncoder)),
    )


# --- Request/Response models ---

class RecognizeRequestBody(BaseModel):
    image: str
    subject: Optional[str] = None
    grade: Optional[str] = None


class ConfirmRequestBody(BaseModel):
    question_text: str
    answer: Optional[str] = None
    knowledge_points: list[str]


class ReviewResultBody(BaseModel):
    correct: bool


# --- Recognize endpoint ---

@router.post("/recognize")
def recognize_endpoint(body: RecognizeRequestBody, request: Request):
    provider = request.app.state.recognition_provider

    req = RecognizeRequest(
        image=body.image,
        subject=body.subject,
        grade=body.grade,
    )

    result = recognize_service(req, provider)

    if isinstance(result, ErrorResponse):
        status_code = _error_code_to_status(result.error.code)
        return JSONResponse(
            status_code=status_code,
            content={
                "error": {
                    "code": result.error.code,
                    "message": result.error.message,
                    "request_id": result.error.request_id,
                }
            },
        )

    # Save to DynamoDB
    saved = db.save_question(
        question_text=result.question_text,
        answer=result.answer,
        knowledge_points=result.knowledge_points,
        confidence=result.confidence,
        status=result.status,
        raw_model_output_id=result.raw_model_output_id,
        subject=body.subject,
        grade=body.grade,
    )

    return JSONResponse(
        status_code=200,
        content={
            "question_id": saved["question_id"],
            "question_text": result.question_text,
            "answer": result.answer,
            "knowledge_points": result.knowledge_points,
            "confidence": result.confidence,
            "status": result.status,
            "raw_model_output_id": result.raw_model_output_id,
        },
    )


# --- Questions CRUD ---

@router.get("/questions")
def list_questions(status: Optional[str] = None):
    items = db.list_questions(status_filter=status)
    return _json_response({"questions": items})


@router.get("/questions/{question_id}")
def get_question(question_id: str):
    item = db.get_question(question_id)
    if not item:
        return JSONResponse(status_code=404, content={"error": "Question not found"})
    return _json_response(item)


@router.post("/questions/{question_id}/confirm")
def confirm_question(question_id: str, body: ConfirmRequestBody):
    if not body.knowledge_points:
        return JSONResponse(
            status_code=400,
            content={"error": "At least one knowledge point is required"},
        )
    updated = db.confirm_question(
        question_id=question_id,
        question_text=body.question_text,
        answer=body.answer,
        knowledge_points=body.knowledge_points,
    )
    if not updated:
        return JSONResponse(status_code=404, content={"error": "Question not found"})
    return _json_response(updated)


@router.post("/questions/{question_id}/discard")
def discard_question(question_id: str):
    db.discard_question(question_id)
    return JSONResponse(status_code=200, content={"ok": True})


# --- Review endpoints ---

@router.get("/review")
def get_review_list():
    items = db.get_review_questions()
    return _json_response({"questions": items})


@router.post("/review/{question_id}")
def submit_review(question_id: str, body: ReviewResultBody):
    updated = db.record_review_result(question_id, body.correct)
    if not updated:
        return JSONResponse(status_code=404, content={"error": "Question not found"})
    return _json_response(updated)


# --- Helper ---

def _error_code_to_status(code: str) -> int:
    mapping = {
        "invalid_image": 400,
        "recognition_unavailable": 502,
        "invalid_model_output": 502,
    }
    return mapping.get(code, 500)
