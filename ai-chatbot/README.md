# 🤖 AI Chatbot — Serverless on AWS

A production-ready AI chatbot built with **AWS Lambda**, **API Gateway**, **S3 static hosting**, and **Claude (Anthropic)** as the AI backend.

Built as a demonstration of serverless AI architecture by an AI Engineer.

---

## Architecture

```
User Browser
    │
    ▼
Amazon S3 (Static Website)
  index.html + JS
    │
    ▼  POST /chat
Amazon API Gateway (HTTP API)
    │
    ▼
AWS Lambda (Node.js 20.x)
    │
    ▼
Anthropic Claude API
```

---

## Project Structure

```
ai-chatbot/
├── frontend/
│   └── index.html          # Full chatbot UI (HTML/CSS/JS)
├── lambda/
│   ├── index.js            # Lambda handler — calls Claude API
│   ├── package.json        # Node dependencies
│   └── test.js             # Local test script
├── infrastructure/
│   ├── deploy.sh           # One-command AWS deployment
│   └── teardown.sh         # Remove all AWS resources
├── .gitignore
└── README.md
```

---

## Prerequisites

- [Node.js 18+](https://nodejs.org)
- [AWS CLI](https://aws.amazon.com/cli/) configured (`aws configure`)
- An [Anthropic API key](https://console.anthropic.com)

---

## Quick Start

### 1. Clone the repo

```bash
git clone https://github.com/YOUR_USERNAME/ai-chatbot.git
cd ai-chatbot
```

### 2. Set your API key

Open `infrastructure/deploy.sh` and replace:

```bash
ANTHROPIC_API_KEY="YOUR_ANTHROPIC_API_KEY_HERE"
```

### 3. Deploy to AWS

```bash
chmod +x infrastructure/deploy.sh
./infrastructure/deploy.sh
```

The script will:
- Package and deploy the Lambda function
- Create an HTTP API Gateway with CORS configured
- Create and configure an S3 bucket for static hosting
- Update the frontend with your API URL
- Print your live URLs at the end

### 4. Test locally (optional)

```bash
cd lambda
npm install
ANTHROPIC_API_KEY=your_key node test.js
```

---

## Configuration

| Variable | Location | Description |
|---|---|---|
| `ANTHROPIC_API_KEY` | `deploy.sh` / Lambda env | Your Anthropic API key |
| `ALLOWED_ORIGIN` | Lambda env vars | Restrict CORS to your S3 URL |
| `API_URL` | `frontend/index.html` | Auto-set by deploy script |
| `REGION` | `deploy.sh` | AWS region (default: us-east-1) |

---

## Features

- 💬 Multi-turn conversation with message history
- ⚡ Serverless — scales to zero, no servers to manage
- 🌐 Fully deployed on AWS (Lambda + API Gateway + S3)
- 🔒 CORS configured, API key stored in Lambda environment
- 📱 Responsive UI — works on mobile and desktop
- ✨ Typing indicator and smooth animations

---

## Cleanup

To remove all AWS resources:

```bash
./infrastructure/teardown.sh
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | HTML5, CSS3, Vanilla JS |
| Hosting | Amazon S3 Static Website |
| API Layer | Amazon API Gateway (HTTP API) |
| Compute | AWS Lambda (Node.js 20.x) |
| AI Model | Anthropic Claude (claude-sonnet-4) |

---

## License

MIT — feel free to fork, modify, and use.
