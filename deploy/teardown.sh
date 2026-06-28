#!/bin/bash
# Teardown all deployed resources
# Usage: ./deploy/teardown.sh

set -euo pipefail

FUNCTION_NAME="cuotiben-recognize"
REGION="${AWS_REGION:-us-west-2}"
ROLE_NAME="cuotiben-lambda-role"
API_NAME="cuotiben-api"

echo "=== Teardown Cuotiben Recognition API ==="
echo ""

# Delete API Gateway
echo "Deleting API Gateway..."
API_ID=$(aws apigatewayv2 get-apis --region "$REGION" \
    --query "Items[?Name=='$API_NAME'].ApiId | [0]" --output text 2>/dev/null || echo "None")
if [ "$API_ID" != "None" ] && [ -n "$API_ID" ]; then
    aws apigatewayv2 delete-api --api-id "$API_ID" --region "$REGION"
    echo "  Deleted API: $API_ID"
else
    echo "  No API found"
fi

# Delete Lambda
echo "Deleting Lambda function..."
aws lambda delete-function --function-name "$FUNCTION_NAME" --region "$REGION" 2>/dev/null && \
    echo "  Deleted: $FUNCTION_NAME" || echo "  Not found"

# Delete IAM role
echo "Deleting IAM role..."
aws iam detach-role-policy --role-name "$ROLE_NAME" \
    --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole" 2>/dev/null || true
aws iam delete-role-policy --role-name "$ROLE_NAME" --policy-name "bedrock-invoke" 2>/dev/null || true
aws iam delete-role --role-name "$ROLE_NAME" 2>/dev/null && \
    echo "  Deleted: $ROLE_NAME" || echo "  Not found"

# Clean up local files
rm -f deploy/lambda-package.zip deploy/api-endpoint.txt

echo ""
echo "Teardown complete."
