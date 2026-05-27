#!/bin/bash
# teardown.sh — Remove all AWS resources
# Usage: ./infrastructure/teardown.sh

LAMBDA_FUNCTION_NAME="ai-chatbot-handler"
REGION="us-east-1"

echo "⚠️  This will delete all AI Chatbot AWS resources."
read -p "Are you sure? (yes/no): " confirm
[ "$confirm" != "yes" ] && echo "Aborted." && exit 0

echo "🗑  Deleting Lambda function..."
aws lambda delete-function --function-name $LAMBDA_FUNCTION_NAME --region $REGION 2>/dev/null && echo "✅ Lambda deleted" || echo "  Lambda not found"

echo "🗑  Deleting API Gateway..."
API_ID=$(aws apigatewayv2 get-apis --region $REGION --query "Items[?Name=='ai-chatbot-api'].ApiId" --output text)
[ -n "$API_ID" ] && aws apigatewayv2 delete-api --api-id $API_ID --region $REGION && echo "✅ API Gateway deleted" || echo "  API Gateway not found"

echo "🗑  Deleting IAM role..."
aws iam detach-role-policy --role-name "${LAMBDA_FUNCTION_NAME}-role" --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole 2>/dev/null || true
aws iam delete-role --role-name "${LAMBDA_FUNCTION_NAME}-role" 2>/dev/null && echo "✅ IAM role deleted" || echo "  IAM role not found"

echo ""
echo "✅ Teardown complete."
echo "Note: Manually delete your S3 bucket from the AWS console."
