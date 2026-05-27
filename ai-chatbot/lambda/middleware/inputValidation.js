"use strict";

const MAX_MESSAGE_BYTES = 10 * 1024; // 10KB
const MAX_HISTORY_TURNS = 20;
const ALLOWED_ROLES = new Set(["user", "assistant"]);

function sanitizeString(str) {
  if (typeof str !== "string") return "";
  // Strip null bytes and control characters (except newline/tab)
  return str.replace(/\x00/g, "").replace(/[\x01-\x08\x0B\x0C\x0E-\x1F\x7F]/g, "");
}

function validateAndParseBody(rawBody) {
  if (!rawBody || typeof rawBody !== "string") {
    return { error: "Request body is required", statusCode: 400 };
  }

  let body;
  try {
    body = JSON.parse(rawBody);
  } catch {
    return { error: "Invalid JSON", statusCode: 400 };
  }

  const { message, history = [] } = body;

  if (!message || typeof message !== "string") {
    return { error: "message is required and must be a string", statusCode: 400 };
  }

  if (Buffer.byteLength(message, "utf8") > MAX_MESSAGE_BYTES) {
    return { error: "message exceeds maximum allowed size", statusCode: 400 };
  }

  const cleanMessage = sanitizeString(message.trim());
  if (cleanMessage.length === 0) {
    return { error: "message cannot be empty", statusCode: 400 };
  }

  if (!Array.isArray(history)) {
    return { error: "history must be an array", statusCode: 400 };
  }

  const validHistory = history
    .slice(-MAX_HISTORY_TURNS)
    .filter((h) => h && ALLOWED_ROLES.has(h.role) && typeof h.content === "string")
    .map((h) => ({ role: h.role, content: sanitizeString(h.content) }));

  return { message: cleanMessage, history: validHistory };
}

module.exports = { validateAndParseBody };
