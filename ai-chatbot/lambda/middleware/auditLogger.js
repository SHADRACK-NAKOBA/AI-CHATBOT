"use strict";

const ENVIRONMENT = process.env.ENVIRONMENT || "dev";

function buildAuditEntry({
  requestId,
  ipHash,
  event,
  outcome,
  blockReason = null,
  inputLength = 0,
  outputLength = 0,
  model = null,
  tokensUsed = null,
  responsibleAI = {},
  durationMs = 0,
  statusCode = 200,
}) {
  return {
    timestamp: new Date().toISOString(),
    requestId,
    clientIp: ipHash || "unknown",
    environment: ENVIRONMENT,
    event,
    outcome,
    blockReason,
    inputLength,
    outputLength,
    model,
    tokensUsed,
    responsibleAI: {
      piiDetected: responsibleAI.piiDetected || false,
      piiTypes: responsibleAI.piiTypes || [],
      harmfulContentBlocked: responsibleAI.harmfulContentBlocked || false,
      blockCategory: responsibleAI.blockCategory || null,
      promptInjectionAttempt: responsibleAI.promptInjectionAttempt || false,
    },
    durationMs,
    statusCode,
  };
}

function writeAuditLog(entry) {
  // CloudWatch Logs captures stdout — structured JSON is queryable via Log Insights
  console.log(JSON.stringify(entry));
}

module.exports = { buildAuditEntry, writeAuditLog };
