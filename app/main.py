"""FastAPI application entry point."""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.recognition.api import router as recognition_router
from app.recognition.bedrock_provider import BedrockRecognitionProvider


def create_app(provider=None) -> FastAPI:
    app = FastAPI(title="Cuotiben Recognition API", version="1.0.0")
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.include_router(recognition_router)

    if provider is None:
        provider = BedrockRecognitionProvider()
    app.state.recognition_provider = provider

    return app


app = create_app()
