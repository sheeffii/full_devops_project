# Application Usage Guide

## Overview

A simple Node.js application with Express, featuring a `/health` endpoint for monitoring and basic smoke testing.

## Prerequisites

- Node.js 20+
- npm

## Local Development

### 1. Install Dependencies

```bash
cd devop-2-main/app
npm install
```

### 2. Run the Application

```bash
npm start
```

The application will start on `http://localhost:3000`

### 3. Test the Health Endpoint

```bash
curl http://localhost:3000/health
```

Expected response:
```json
{"status":"OK","message":"Server is healthy"}
```

### 4. Run Smoke Tests

```bash
npm test
```

## Docker Deployment

### Build the Docker Image

```bash
cd devop-2-main
docker build -t devops2-app .
```

### Run Container

```bash
docker run -d -p 3000:3000 --name devops2-container devops2-app
```

### Test Container

```bash
curl http://localhost:3000/health
```

### Stop Container

```bash
docker stop devops2-container
docker rm devops2-container
```

## Production Deployment

The application is automatically deployed to AWS EC2 via GitHub Actions CI/CD pipeline when changes are pushed to the main branch.

See [../../docs/ci.md](../../docs/ci.md) for complete CI/CD documentation.

## Project Structure

```
devop-2-main/
├── app/
│   ├── app.js          # Express server with /health endpoint
│   ├── test.js         # Smoke test script
│   ├── package.json    # Dependencies
│   └── package-lock.json
├── Dockerfile          # Multi-stage Docker build
└── docs/
    └── app.md         # This file
```

## Endpoints

- `GET /` - Welcome message
- `GET /health` - Health check endpoint (returns JSON status)

## Technologies

- **Express**: Web framework
- **Node.js**: Runtime environment
- **Docker**: Containerization