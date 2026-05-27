"use strict";

// Patterns that result in an immediate 400 rejection — not sent to Claude at all
const ABSOLUTE_BLOCK_PATTERNS = [
  /child\s+(?:pornography|sexual\s+abuse|exploitation)/i,
  /CSAM/i,
  /(?:synthesize|manufacture|make|build|create)\s+(?:bioweapon|chemical\s+weapon|nerve\s+agent|sarin|VX\s+gas|novichok)/i,
  /(?:enrich|weaponize)\s+uranium/i,
  /(?:create|build|write)\s+(?:malware|ransomware|keylogger|rootkit|exploit)\s+(?:for\s+me|that\s+will)/i,
  /ignore\s+(?:previous|all|above|your)\s+instructions?/i,
  /you\s+are\s+now\s+(?:DAN|evil|unrestricted|without\s+restrictions)/i,
  /pretend\s+(?:you\s+have\s+no\s+restrictions|there\s+are\s+no\s+rules|you\s+can\s+do\s+anything)/i,
  /(?:developer|god|admin)\s+mode\s+(?:enabled|activated|on)/i,
  /jailbreak/i,
];

// Patterns that signal a prompt injection attempt
const PROMPT_INJECTION_PATTERNS = [
  /<\s*system\s*>/i,
  /\[SYSTEM\]/i,
  /\[INST\]/i,
  /human:\s/i,
  /assistant:\s/i,
  /system\s*prompt\s*[:=]/i,
  /\n{3,}.*(?:ignore|forget|disregard)/i,
];

// PII patterns — matched content is REPLACED before sending to Claude
const PII_PATTERNS = [
  { name: "email", pattern: /[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}/g, replacement: "[EMAIL REDACTED]" },
  { name: "phone", pattern: /(?:\+?1[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}/g, replacement: "[PHONE REDACTED]" },
  { name: "ssn", pattern: /\b\d{3}-\d{2}-\d{4}\b/g, replacement: "[SSN REDACTED]" },
  { name: "credit_card", pattern: /\b(?:\d{4}[-\s]?){3}\d{4}\b/g, replacement: "[CARD REDACTED]" },
  { name: "aws_key", pattern: /(?:AKIA|ABIA|ACCA|ASIA)[A-Z0-9]{16}/g, replacement: "[AWS KEY REDACTED]" },
];

function inspectMessage(message) {
  const detectedPii = [];
  let sanitizedMessage = message;
  let harmfulContentBlocked = false;
  let promptInjectionAttempt = false;
  let blockCategory = null;

  // Check absolute blocks first — reject before any further processing
  for (const pattern of ABSOLUTE_BLOCK_PATTERNS) {
    if (pattern.test(message)) {
      harmfulContentBlocked = true;
      blockCategory = "harmful_content";
      break;
    }
  }

  if (!harmfulContentBlocked) {
    // Check for prompt injection
    for (const pattern of PROMPT_INJECTION_PATTERNS) {
      if (pattern.test(message)) {
        promptInjectionAttempt = true;
        // Sanitize injection markers rather than block (log and continue)
        sanitizedMessage = sanitizedMessage.replace(pattern, "[FILTERED]");
      }
    }

    // PII detection and redaction
    for (const { name, pattern, replacement } of PII_PATTERNS) {
      if (pattern.test(sanitizedMessage)) {
        detectedPii.push(name);
        sanitizedMessage = sanitizedMessage.replace(pattern, replacement);
      }
    }
  }

  return {
    harmfulContentBlocked,
    blockCategory,
    promptInjectionAttempt,
    piiDetected: detectedPii.length > 0,
    piiTypes: detectedPii,
    sanitizedMessage,
  };
}

module.exports = { inspectMessage };
