import io
import httpx
from PIL import Image
from app.core.config import settings


class OCRService:
    def __init__(self):
        self.ocr_url = f"{settings.ocr_service_url}/ocr"
        self.mode = settings.ocr_mode

    async def recognize(self, image_data: bytes) -> list[str]:
        # Try Docker OCR service first
        if self.mode in ("docker", "auto"):
            try:
                return await self._docker_ocr(image_data)
            except (httpx.ConnectError, httpx.TimeoutException, httpx.HTTPStatusError):
                if self.mode == "docker":
                    raise OCRServiceError(
                        "OCR Docker service is not running on port 8866. "
                        "Please start it with: docker compose up -d"
                    )

        # Fallback: mock mode for development/testing
        return self._mock_ocr(image_data)

    async def _docker_ocr(self, image_data: bytes) -> list[str]:
        async with httpx.AsyncClient(timeout=30.0) as client:
            files = {"file": ("image.jpg", image_data, "image/jpeg")}
            response = await client.post(self.ocr_url, files=files)
            response.raise_for_status()
            data = response.json()

        words = []
        for item in data.get("data", []):
            text = item.get("text", "").strip()
            if text and self._is_valid_word(text):
                words.append(text)

        # Case-insensitive dedup preserving order and first-occurrence casing
        seen = set()
        unique = []
        for w in words:
            key = w.lower()
            if key not in seen:
                unique.append(w)
                seen.add(key)
        return unique

    def _mock_ocr(self, image_data: bytes) -> list[str]:
        """Mock OCR: extracts basic image info and returns sample words."""
        try:
            img = Image.open(io.BytesIO(image_data))
            width, height = img.size
            size_kb = len(image_data) / 1024
        except Exception:
            width, height, size_kb = 0, 0, 0

        base_words = ["apple", "book", "cat", "dog", "english", "flower",
                      "green", "happy", "learn", "moon", "sun", "tree",
                      "water", "window", "yellow"]
        count = min(max(3, (width * height) // 200000), len(base_words))
        return base_words[:count]

    def _is_valid_word(self, text: str) -> bool:
        if len(text) < 1:
            return False
        if not any(c.isalpha() for c in text):
            return False
        return True


class OCRServiceError(Exception):
    pass
