"""Auth API endpoints."""

from fastapi import APIRouter
from fastapi.responses import JSONResponse
from pydantic import BaseModel

from app.auth import db
from app.auth.jwt_util import create_token, verify_token

router = APIRouter(prefix="/auth")


class RegisterBody(BaseModel):
    username: str
    password: str
    role: str  # "parent" or "student"


class LoginBody(BaseModel):
    username: str
    password: str


class TokenBody(BaseModel):
    token: str


@router.post("/register")
def register(body: RegisterBody):
    if not body.username or not body.password:
        return JSONResponse(status_code=400, content={"error": "Username and password required"})
    if body.role not in ("parent", "student"):
        return JSONResponse(status_code=400, content={"error": "Role must be 'parent' or 'student'"})
    if len(body.username) < 2 or len(body.username) > 20:
        return JSONResponse(status_code=400, content={"error": "Username must be 2-20 characters"})
    if len(body.password) < 4:
        return JSONResponse(status_code=400, content={"error": "Password must be at least 4 characters"})

    result = db.register(body.username, body.password, body.role)
    if not result:
        return JSONResponse(status_code=409, content={"error": "Username already exists"})

    token = create_token(result["username"], result["role"])
    return JSONResponse(status_code=201, content={
        "username": result["username"],
        "role": result["role"],
        "token": token,
    })


@router.post("/login")
def login(body: LoginBody):
    if not body.username or not body.password:
        return JSONResponse(status_code=400, content={"error": "Username and password required"})

    user = db.authenticate(body.username, body.password)
    if not user:
        return JSONResponse(status_code=401, content={"error": "Invalid username or password"})

    token = create_token(user["username"], user["role"])
    return JSONResponse(status_code=200, content={
        "username": user["username"],
        "role": user["role"],
        "token": token,
    })


@router.post("/verify")
def verify(body: TokenBody):
    payload = verify_token(body.token)
    if not payload:
        return JSONResponse(status_code=401, content={"error": "Invalid or expired token"})
    return JSONResponse(status_code=200, content={
        "username": payload["username"],
        "role": payload["role"],
    })
