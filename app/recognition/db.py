"""DynamoDB persistence for questions."""

import time
import uuid
from typing import Optional

import boto3
from boto3.dynamodb.conditions import Key

TABLE_NAME = "cuotiben-questions"
REGION = "us-east-1"
IMAGE_BUCKET = "cuotiben-frontend-375297"
IMAGE_PREFIX = "images/"


def _get_table():
    dynamodb = boto3.resource("dynamodb", region_name=REGION)
    return dynamodb.Table(TABLE_NAME)


def _get_s3():
    return boto3.client("s3", region_name=REGION)


def upload_image(question_id: str, image_bytes: bytes, content_type: str = "image/jpeg") -> str:
    s3 = _get_s3()
    key = f"{IMAGE_PREFIX}{question_id}.jpg"
    if content_type == "image/png":
        key = f"{IMAGE_PREFIX}{question_id}.png"
    s3.put_object(
        Bucket=IMAGE_BUCKET,
        Key=key,
        Body=image_bytes,
        ContentType=content_type,
    )
    return f"http://{IMAGE_BUCKET}.s3-website-us-east-1.amazonaws.com/{key}"


def update_image_url(question_id: str, image_url: str) -> None:
    table = _get_table()
    table.update_item(
        Key={"question_id": question_id},
        UpdateExpression="SET image_url = :url",
        ExpressionAttributeValues={":url": image_url},
    )


def save_question(
    question_text: str,
    answer: Optional[str],
    knowledge_points: list[str],
    confidence: float,
    status: str,
    raw_model_output_id: str,
    subject: Optional[str] = None,
    grade: Optional[str] = None,
    image_url: Optional[str] = None,
) -> dict:
    table = _get_table()
    question_id = f"q_{uuid.uuid4().hex[:12]}"
    now = int(time.time())
    item = {
        "question_id": question_id,
        "question_text": question_text,
        "answer": answer or "",
        "knowledge_points": knowledge_points,
        "confidence": str(confidence),
        "status": status,
        "raw_model_output_id": raw_model_output_id,
        "subject": subject or "",
        "grade": grade or "",
        "created_at": now,
        "updated_at": now,
        "confirmed_by_user": False,
        "review_count": 0,
        "correct_streak": 0,
        "mastery": "unmastered",
        "image_url": image_url or "",
    }
    table.put_item(Item=item)
    return item


def list_questions(status_filter: Optional[str] = None) -> list[dict]:
    table = _get_table()
    if status_filter:
        response = table.scan(
            FilterExpression="#s = :status",
            ExpressionAttributeNames={"#s": "status"},
            ExpressionAttributeValues={":status": status_filter},
        )
    else:
        response = table.scan()
    items = response.get("Items", [])
    items.sort(key=lambda x: x.get("created_at", 0), reverse=True)
    return items


def get_question(question_id: str) -> Optional[dict]:
    table = _get_table()
    response = table.get_item(Key={"question_id": question_id})
    return response.get("Item")


def confirm_question(
    question_id: str,
    question_text: str,
    answer: Optional[str],
    knowledge_points: list[str],
) -> Optional[dict]:
    table = _get_table()
    now = int(time.time())
    response = table.update_item(
        Key={"question_id": question_id},
        UpdateExpression=(
            "SET question_text = :qt, answer = :ans, knowledge_points = :kp, "
            "#s = :status, confirmed_by_user = :confirmed, updated_at = :now"
        ),
        ExpressionAttributeNames={"#s": "status"},
        ExpressionAttributeValues={
            ":qt": question_text,
            ":ans": answer or "",
            ":kp": knowledge_points,
            ":status": "confirmed",
            ":confirmed": True,
            ":now": now,
        },
        ReturnValues="ALL_NEW",
    )
    return response.get("Attributes")


def discard_question(question_id: str) -> bool:
    table = _get_table()
    table.delete_item(Key={"question_id": question_id})
    return True


def get_review_questions() -> list[dict]:
    """Get confirmed questions that are not yet mastered for review."""
    table = _get_table()
    response = table.scan(
        FilterExpression="#s = :status AND mastery <> :mastered",
        ExpressionAttributeNames={"#s": "status"},
        ExpressionAttributeValues={
            ":status": "confirmed",
            ":mastered": "mastered",
        },
    )
    items = response.get("Items", [])
    items.sort(key=lambda x: int(x.get("correct_streak", 0)))
    return items


def record_review_result(question_id: str, correct: bool) -> Optional[dict]:
    """Record a review result. 3 consecutive correct -> mastered."""
    table = _get_table()
    item = get_question(question_id)
    if not item:
        return None

    now = int(time.time())
    review_count = int(item.get("review_count", 0)) + 1

    if correct:
        correct_streak = int(item.get("correct_streak", 0)) + 1
    else:
        correct_streak = 0

    mastery = "mastered" if correct_streak >= 3 else "unmastered"

    response = table.update_item(
        Key={"question_id": question_id},
        UpdateExpression=(
            "SET review_count = :rc, correct_streak = :cs, "
            "mastery = :m, updated_at = :now, last_review_at = :now"
        ),
        ExpressionAttributeValues={
            ":rc": review_count,
            ":cs": correct_streak,
            ":m": mastery,
            ":now": now,
        },
        ReturnValues="ALL_NEW",
    )
    return response.get("Attributes")


def edit_question(
    question_id: str,
    question_text: str,
    answer: Optional[str],
    knowledge_points: list[str],
) -> Optional[dict]:
    table = _get_table()
    now = int(time.time())
    response = table.update_item(
        Key={"question_id": question_id},
        UpdateExpression=(
            "SET question_text = :qt, answer = :ans, knowledge_points = :kp, updated_at = :now"
        ),
        ExpressionAttributeValues={
            ":qt": question_text,
            ":ans": answer or "",
            ":kp": knowledge_points,
            ":now": now,
        },
        ReturnValues="ALL_NEW",
    )
    return response.get("Attributes")


def batch_delete_questions(question_ids: list[str]) -> int:
    table = _get_table()
    deleted = 0
    for qid in question_ids:
        table.delete_item(Key={"question_id": qid})
        deleted += 1
    return deleted
