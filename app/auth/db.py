"""DynamoDB persistence for users."""

import hashlib
import os
import time
from typing import Optional

import boto3

TABLE_NAME = "cuotiben-users"
REGION = "us-east-1"


def _get_table():
    dynamodb = boto3.resource("dynamodb", region_name=REGION)
    return dynamodb.Table(TABLE_NAME)


def _hash_password(password: str, salt: str) -> str:
    return hashlib.sha256((salt + password).encode()).hexdigest()


def register(username: str, password: str, role: str) -> dict | None:
    table = _get_table()
    salt = os.urandom(16).hex()
    password_hash = _hash_password(password, salt)
    now = int(time.time())
    item = {
        "username": username,
        "password_hash": password_hash,
        "salt": salt,
        "role": role,
        "created_at": now,
    }
    try:
        table.put_item(
            Item=item,
            ConditionExpression="attribute_not_exists(username)",
        )
        return {"username": username, "role": role}
    except table.meta.client.exceptions.ConditionalCheckFailedException:
        return None


def authenticate(username: str, password: str) -> Optional[dict]:
    table = _get_table()
    response = table.get_item(Key={"username": username})
    item = response.get("Item")
    if not item:
        return None
    password_hash = _hash_password(password, item["salt"])
    if password_hash != item["password_hash"]:
        return None
    return {"username": item["username"], "role": item["role"]}
