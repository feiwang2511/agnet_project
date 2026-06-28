"""AWS Lambda entry point using Mangum to wrap FastAPI."""

from mangum import Mangum

from app.main import create_app
from app.recognition.bedrock_provider import BedrockRecognitionProvider

app = create_app(provider=BedrockRecognitionProvider())
handler = Mangum(app, lifespan="off", api_gateway_base_path="/prod")
