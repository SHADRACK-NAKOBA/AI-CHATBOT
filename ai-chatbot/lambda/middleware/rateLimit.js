"use strict";

const { DynamoDBClient, UpdateItemCommand, GetItemCommand } = require("@aws-sdk/client-dynamodb");

const TABLE_NAME = process.env.RATE_LIMIT_TABLE || "nakoba-rate-limits";
const WINDOW_SECONDS = 60;
const MAX_REQUESTS = parseInt(process.env.RATE_LIMIT_MAX || "100", 10);

const dynamo = new DynamoDBClient({ region: process.env.AWS_REGION || "us-east-1" });

function hashIp(ip) {
  const crypto = require("crypto");
  return crypto.createHash("sha256").update(ip + process.env.RATE_LIMIT_SALT || "nakoba").digest("hex").slice(0, 16);
}

function getClientIp(event) {
  return (
    event.headers?.["x-forwarded-for"]?.split(",")[0]?.trim() ||
    event.requestContext?.http?.sourceIp ||
    event.requestContext?.identity?.sourceIp ||
    "unknown"
  );
}

async function checkRateLimit(event) {
  const rawIp = getClientIp(event);
  const ipHash = hashIp(rawIp);
  const windowKey = `${ipHash}:${Math.floor(Date.now() / 1000 / WINDOW_SECONDS)}`;
  const ttl = Math.floor(Date.now() / 1000) + WINDOW_SECONDS * 2;

  try {
    const result = await dynamo.send(new UpdateItemCommand({
      TableName: TABLE_NAME,
      Key: { pk: { S: windowKey } },
      UpdateExpression: "ADD #count :inc SET #ttl = if_not_exists(#ttl, :ttl)",
      ExpressionAttributeNames: { "#count": "count", "#ttl": "ttl" },
      ExpressionAttributeValues: {
        ":inc": { N: "1" },
        ":ttl": { N: String(ttl) },
      },
      ReturnValues: "UPDATED_NEW",
    }));

    const currentCount = parseInt(result.Attributes?.count?.N || "1", 10);
    const remaining = Math.max(0, MAX_REQUESTS - currentCount);

    return {
      allowed: currentCount <= MAX_REQUESTS,
      remaining,
      limit: MAX_REQUESTS,
      ipHash,
    };
  } catch (err) {
    // If DynamoDB is unreachable, fail open with a warning (availability > rate limiting)
    console.warn(JSON.stringify({ event: "rate_limit_check_failed", error: err.message }));
    return { allowed: true, remaining: MAX_REQUESTS, limit: MAX_REQUESTS, ipHash };
  }
}

module.exports = { checkRateLimit };
