# AI English Learning App

AI-powered English learning application with OCR recognition, story generation, and exercise creation.

## Tech Stack

- **Frontend**: Flutter (mobile/web)
- **Backend**: FastAPI (Python)
- **OCR**: PaddleOCR (Docker)
- **AI**: DeepSeek API

## Project Structure

```
english_learning_app/
├── frontend_flutter/      # Flutter mobile app
├── backend_fastapi/       # FastAPI backend service
├── docker/                # Docker configuration
├── docs/                  # Documentation
└── README.md
```

## Quick Start

### 1. Start OCR Service
```bash
cd docker
docker compose up -d
```

### 2. Start Backend
```bash
cd backend_fastapi
pip install -r requirements.txt
uvicorn main:app --reload
```

### 3. Start Frontend
```bash
cd frontend_flutter
flutter pub get
flutter run
```

## Ports

| Service     | Port |
|-------------|------|
| Flutter App | 3000 |
| FastAPI     | 8000 |
| PaddleOCR   | 8866 |

## Environment Variables

Copy `.env.example` to `.env` and configure:
- `DEEPSEEK_API_KEY`: Your DeepSeek API key
- `DATABASE_URL`: Database connection string
- `OCR_SERVICE_URL`: OCR service endpoint
