// Run locally: node test.js
// Make sure ANTHROPIC_API_KEY is set in your environment

const { handler } = require("./index");

async function runTest() {
  const event = {
    httpMethod: "POST",
    body: JSON.stringify({
      message: "Hello! What can you help me with?",
      history: [],
    }),
  };

  console.log("Sending test event to Lambda handler...\n");
  const result = await handler(event);
  console.log("Status:", result.statusCode);
  console.log("Response:", JSON.parse(result.body));
}

runTest().catch(console.error);
