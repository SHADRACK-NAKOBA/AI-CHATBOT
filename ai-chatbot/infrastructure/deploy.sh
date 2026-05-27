#!/bin/bash
# deploy.sh — Deploy AI Chatbot to AWS
# Usage: ./infrastructure/deploy.sh
# Requirements: AWS CLI configured, Node.js installed

set -e

# ── CONFIG (edit these) ──────────────────────────────────
STACK_NAME="ai-chatbot"
REGION="us-east-1"
LAMBDA_FUNCTION_NAME="ai-chatbot-handler"
S3_BUCKET_NAME="ai-chatbot-frontend-$(date +%s)"   # unique bucket name
ANTHROPIC_API_KEY="YOUR_ANTHROPIC_API_KEY_HERE"
# ─────────────────────────────────────────────────────────

echo "🚀 Deploying AI Chatbot to AWS..."
echo "Region: $REGION"
echo ""

# Step 1: Install Lambda dependencies and package
echo "📦 Packaging Lambda function..."
cd lambda
npm install --production
zip -r ../lambda.zip . -x "*.test.js" "test.js"
cd ..
echo "✅ Lambda packaged → lambda.zip"

# Step 2: Create or update Lambda function
echo ""
echo "⚡ Deploying Lambda function..."

# Check if function exists
if aws lambda get-function --function-name $LAMBDA_FUNCTION_NAME --region $REGION &>/dev/null; then
  echo "   Updating existing Lambda..."
  aws lambda update-function-code \
    --function-name $LAMBDA_FUNCTION_NAME \
    --zip-file fileb://lambda.zip \
    --region $REGION
else
  echo "   Creating new Lambda..."
  # Create execution role first
  ROLE_ARN=$(aws iam create-role \
    --role-name "${LAMBDA_FUNCTION_NAME}-role" \
    --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}' \
    --query 'Role.Arn' --output text 2>/dev/null || \
    aws iam get-role --role-name "${LAMBDA_FUNCTION_NAME}-role" --query 'Role.Arn' --output text)

  aws iam attach-role-policy \
    --role-name "${LAMBDA_FUNCTION_NAME}-role" \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole 2>/dev/null || true

  sleep 5  # Wait for role propagation

  aws lambda create-function \
    --function-name $LAMBDA_FUNCTION_NAME \
    --runtime nodejs20.x \
    --role $ROLE_ARN \
    --handler index.handler \
    --zip-file fileb://lambda.zip \
    --timeout 30 \
    --memory-size 256 \
    --environment "Variables={ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY}" \
    --region $REGION
fi

echo "✅ Lambda deployed"

# Step 3: Create API Gateway
echo ""
echo "🌐 Setting up API Gateway..."

API_ID=$(aws apigatewayv2 create-api \
  --name "${STACK_NAME}-api" \
  --protocol-type HTTP \
  --cors-configuration AllowOrigins="*",AllowMethods="POST,OPTIONS",AllowHeaders="Content-Type" \
  --query 'ApiId' --output text --region $REGION)

LAMBDA_ARN=$(aws lambda get-function \
  --function-name $LAMBDA_FUNCTION_NAME \
  --query 'Configuration.FunctionArn' --output text --region $REGION)

# Create integration
INTEGRATION_ID=$(aws apigatewayv2 create-integration \
  --api-id $API_ID \
  --integration-type AWS_PROXY \
  --integration-uri $LAMBDA_ARN \
  --payload-format-version "2.0" \
  --query 'IntegrationId' --output text --region $REGION)

# Create route
aws apigatewayv2 create-route \
  --api-id $API_ID \
  --route-key "POST /chat" \
  --target "integrations/$INTEGRATION_ID" \
  --region $REGION > /dev/null

# Create default stage with auto-deploy
aws apigatewayv2 create-stage \
  --api-id $API_ID \
  --stage-name "prod" \
  --auto-deploy \
  --region $REGION > /dev/null

# Add Lambda permission for API Gateway
aws lambda add-permission \
  --function-name $LAMBDA_FUNCTION_NAME \
  --statement-id "api-gateway-invoke" \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --region $REGION > /dev/null 2>&1 || true

API_URL="https://${API_ID}.execute-api.${REGION}.amazonaws.com/prod"
echo "✅ API Gateway deployed → $API_URL"

# Step 4: Update frontend with API URL
echo ""
echo "📝 Updating frontend with API URL..."
sed -i "s|YOUR_API_GATEWAY_URL/chat|${API_URL}/chat|g" frontend/index.html
echo "✅ Frontend updated"

# Step 5: Deploy frontend to S3
echo ""
echo "☁️  Deploying frontend to S3..."

aws s3 mb s3://$S3_BUCKET_NAME --region $REGION

aws s3 website s3://$S3_BUCKET_NAME \
  --index-document index.html \
  --error-document index.html

# Set bucket policy for public read
aws s3api put-bucket-policy --bucket $S3_BUCKET_NAME --policy "{
  \"Version\": \"2012-10-17\",
  \"Statement\": [{
    \"Sid\": \"PublicReadGetObject\",
    \"Effect\": \"Allow\",
    \"Principal\": \"*\",
    \"Action\": \"s3:GetObject\",
    \"Resource\": \"arn:aws:s3:::${S3_BUCKET_NAME}/*\"
  }]
}"

# Disable public access block (required for static website)
aws s3api put-public-access-block \
  --bucket $S3_BUCKET_NAME \
  --public-access-block-configuration "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false"

aws s3 cp frontend/index.html s3://$S3_BUCKET_NAME/index.html \
  --content-type "text/html"

WEBSITE_URL="http://${S3_BUCKET_NAME}.s3-website-${REGION}.amazonaws.com"
echo "✅ Frontend deployed → $WEBSITE_URL"

# Summary
echo ""
echo "══════════════════════════════════════════"
echo "🎉  DEPLOYMENT COMPLETE"
echo "══════════════════════════════════════════"
echo "  Frontend URL : $WEBSITE_URL"
echo "  API Gateway  : $API_URL/chat"
echo "  Lambda       : $LAMBDA_FUNCTION_NAME"
echo "  S3 Bucket    : $S3_BUCKET_NAME"
echo "══════════════════════════════════════════"

# Cleanup
rm -f lambda.zip
