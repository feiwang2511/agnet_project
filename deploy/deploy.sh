#!/bin/bash
# Deploy the Cuotiben Recognition API to AWS Lambda + API Gateway
# Prerequisites: AWS CLI configured, Python 3.12+, zip

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DEPLOY_DIR="$SCRIPT_DIR"

# Configuration
FUNCTION_NAME="cuotiben-recognize"
REGION="${AWS_REGION:-us-east-1}"
RUNTIME="python3.12"
HANDLER="app.lambda_handler.handler"
TIMEOUT=30
MEMORY=512
ROLE_NAME="cuotiben-lambda-role"
API_NAME="cuotiben-api"
STAGE_NAME="prod"

echo "=== Cuotiben Recognition API Deployment ==="
echo "Region: $REGION"
echo "Function: $FUNCTION_NAME"
echo ""

# --- Step 1: Package Lambda ---
echo "[1/6] Packaging Lambda function..."
PACKAGE_DIR=$(mktemp -d)
PACKAGE_ZIP="$DEPLOY_DIR/lambda-package.zip"

# Install dependencies into package (target Lambda's Linux x86_64)
pip3 install -q -t "$PACKAGE_DIR" \
    --platform manylinux2014_x86_64 \
    --implementation cp \
    --python-version 3.12 \
    --only-binary=:all: \
    fastapi pydantic uvicorn boto3 mangum 2>&1 | tail -3

# Copy application code
cp -r "$PROJECT_DIR/app" "$PACKAGE_DIR/"

# Create ZIP
cd "$PACKAGE_DIR"
rm -f "$PACKAGE_ZIP"
zip -q -r "$PACKAGE_ZIP" . -x '*.pyc' '*/__pycache__/*' '*/tests/*'
cd "$PROJECT_DIR"
rm -rf "$PACKAGE_DIR"
echo "  Package: $PACKAGE_ZIP ($(du -h "$PACKAGE_ZIP" | cut -f1))"

# --- Step 2: Create/Get IAM Role ---
echo "[2/6] Setting up IAM role..."
ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text 2>/dev/null || echo "")

if [ -z "$ROLE_ARN" ]; then
    echo "  Creating role: $ROLE_NAME"
    TRUST_POLICY='{
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Principal": {"Service": "lambda.amazonaws.com"},
            "Action": "sts:AssumeRole"
        }]
    }'
    ROLE_ARN=$(aws iam create-role \
        --role-name "$ROLE_NAME" \
        --assume-role-policy-document "$TRUST_POLICY" \
        --query 'Role.Arn' --output text \
        --region "$REGION")

    # Attach basic Lambda execution policy
    aws iam attach-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"

    # Attach Bedrock invoke policy
    BEDROCK_POLICY='{
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Action": ["bedrock:InvokeModel"],
            "Resource": "*"
        }]
    }'
    aws iam put-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-name "bedrock-invoke" \
        --policy-document "$BEDROCK_POLICY"

    echo "  Waiting for role propagation..."
    sleep 10
else
    echo "  Role exists: $ROLE_ARN"
fi

# --- Step 3: Create/Update Lambda Function ---
echo "[3/6] Deploying Lambda function..."
EXISTING=$(aws lambda get-function --function-name "$FUNCTION_NAME" --region "$REGION" 2>/dev/null || echo "")

if [ -z "$EXISTING" ]; then
    echo "  Creating function: $FUNCTION_NAME"
    aws lambda create-function \
        --function-name "$FUNCTION_NAME" \
        --runtime "$RUNTIME" \
        --handler "$HANDLER" \
        --role "$ROLE_ARN" \
        --zip-file "fileb://$PACKAGE_ZIP" \
        --timeout "$TIMEOUT" \
        --memory-size "$MEMORY" \
        --region "$REGION" \
        --environment "Variables={PYTHONPATH=/var/task}" \
        --query 'FunctionArn' --output text
else
    echo "  Updating function: $FUNCTION_NAME"
    aws lambda update-function-code \
        --function-name "$FUNCTION_NAME" \
        --zip-file "fileb://$PACKAGE_ZIP" \
        --region "$REGION" \
        --query 'FunctionArn' --output text

    # Wait for update to complete
    aws lambda wait function-updated --function-name "$FUNCTION_NAME" --region "$REGION" 2>/dev/null || true

    aws lambda update-function-configuration \
        --function-name "$FUNCTION_NAME" \
        --runtime "$RUNTIME" \
        --handler "$HANDLER" \
        --timeout "$TIMEOUT" \
        --memory-size "$MEMORY" \
        --environment "Variables={PYTHONPATH=/var/task}" \
        --region "$REGION" \
        --query 'FunctionArn' --output text
fi

# --- Step 4: Create API Gateway (HTTP API) ---
echo "[4/6] Setting up API Gateway..."
API_ID=$(aws apigatewayv2 get-apis --region "$REGION" \
    --query "Items[?Name=='$API_NAME'].ApiId | [0]" --output text 2>/dev/null || echo "")

if [ "$API_ID" = "None" ] || [ -z "$API_ID" ]; then
    echo "  Creating HTTP API: $API_NAME"
    API_ID=$(aws apigatewayv2 create-api \
        --name "$API_NAME" \
        --protocol-type HTTP \
        --region "$REGION" \
        --query 'ApiId' --output text)
fi
echo "  API ID: $API_ID"

# --- Step 5: Create Integration + Route ---
echo "[5/6] Configuring routes..."
LAMBDA_ARN=$(aws lambda get-function --function-name "$FUNCTION_NAME" --region "$REGION" \
    --query 'Configuration.FunctionArn' --output text)

# Check for existing integration
INTEGRATION_ID=$(aws apigatewayv2 get-integrations --api-id "$API_ID" --region "$REGION" \
    --query "Items[?IntegrationUri=='$LAMBDA_ARN'].IntegrationId | [0]" --output text 2>/dev/null || echo "")

if [ "$INTEGRATION_ID" = "None" ] || [ -z "$INTEGRATION_ID" ]; then
    INTEGRATION_ID=$(aws apigatewayv2 create-integration \
        --api-id "$API_ID" \
        --integration-type AWS_PROXY \
        --integration-uri "$LAMBDA_ARN" \
        --payload-format-version "2.0" \
        --region "$REGION" \
        --query 'IntegrationId' --output text)
fi

# Create route for POST /recognize
ROUTE_KEY="POST /recognize"
EXISTING_ROUTE=$(aws apigatewayv2 get-routes --api-id "$API_ID" --region "$REGION" \
    --query "Items[?RouteKey=='$ROUTE_KEY'].RouteId | [0]" --output text 2>/dev/null || echo "")

if [ "$EXISTING_ROUTE" = "None" ] || [ -z "$EXISTING_ROUTE" ]; then
    aws apigatewayv2 create-route \
        --api-id "$API_ID" \
        --route-key "$ROUTE_KEY" \
        --target "integrations/$INTEGRATION_ID" \
        --region "$REGION" \
        --query 'RouteId' --output text > /dev/null
fi

# Create default stage
STAGE_EXISTS=$(aws apigatewayv2 get-stages --api-id "$API_ID" --region "$REGION" \
    --query "Items[?StageName=='$STAGE_NAME'].StageName | [0]" --output text 2>/dev/null || echo "")

if [ "$STAGE_EXISTS" = "None" ] || [ -z "$STAGE_EXISTS" ]; then
    aws apigatewayv2 create-stage \
        --api-id "$API_ID" \
        --stage-name "$STAGE_NAME" \
        --auto-deploy \
        --region "$REGION" > /dev/null
else
    aws apigatewayv2 update-stage \
        --api-id "$API_ID" \
        --stage-name "$STAGE_NAME" \
        --auto-deploy \
        --region "$REGION" > /dev/null 2>&1 || true
fi

# Grant API Gateway permission to invoke Lambda
ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
aws lambda add-permission \
    --function-name "$FUNCTION_NAME" \
    --statement-id "apigateway-invoke-$(date +%s)" \
    --action "lambda:InvokeFunction" \
    --principal "apigateway.amazonaws.com" \
    --source-arn "arn:aws:execute-api:$REGION:$ACCOUNT_ID:$API_ID/*" \
    --region "$REGION" > /dev/null 2>&1 || true

# --- Step 6: Output ---
echo "[6/6] Deployment complete!"
echo ""
API_URL="https://$API_ID.execute-api.$REGION.amazonaws.com/$STAGE_NAME"
echo "=========================================="
echo "  API URL: $API_URL"
echo "  Endpoint: POST $API_URL/recognize"
echo "=========================================="
echo ""
echo "Test command:"
echo "  curl -X POST $API_URL/recognize \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"image\": \"<base64-jpeg>\", \"subject\": \"math\", \"grade\": \"grade_7\"}'"
echo ""

# Save endpoint for testing
echo "$API_URL" > "$DEPLOY_DIR/api-endpoint.txt"
echo "Endpoint saved to: $DEPLOY_DIR/api-endpoint.txt"
