import io
import logging
import httpx
from PIL import Image
from app.core.config import settings

logger = logging.getLogger(__name__)


class OCRService:
    def __init__(self):
        self.ocr_url = f"{settings.ocr_service_url}/ocr"
        self.mode = settings.ocr_mode
        if self.mode != "docker":
            logger.warning(
                "OCR mode is %r: OCR may return mock words marked degraded. "
                "Use ocr_mode=docker in production.", self.mode,
            )

    async def recognize(self, image_data: bytes) -> tuple[list[str], str | None]:
        """返回 (词表, 降级 reason)，未降级时 reason 为 None。

        docker 模式下 OCR 不可用时抛 OCRServiceError；auto 模式回落 mock。
        """
        if self.mode == "mock":
            return self._mock_ocr(image_data), "ocr_mock"

        try:
            return await self._docker_ocr(image_data), None
        except httpx.HTTPError as e:
            if self.mode == "docker":
                logger.error(
                    "OCR service call failed (%s): %s; is the OCR container running at %s?",
                    type(e).__name__, e, self.ocr_url,
                )
                raise OCRServiceError("ocr_unavailable") from e
            logger.warning(
                "OCR service call failed (%s): %s; falling back to mock words",
                type(e).__name__, e,
            )
            return self._mock_ocr(image_data), "ocr_unavailable"

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
