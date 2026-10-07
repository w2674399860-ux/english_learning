"""OCRService：docker / auto / mock 三种模式下的成功与失败。"""
import httpx
import pytest
from conftest import OCR_BASE, raiser, tiny_png

from app.services.ocr_service import OCRServiceError

MOCK_FIRST_THREE = ["apple", "book", "cat"]

# 第二阶段 A-3 临时脚本的 OCR 失败类型
FAILURES = {
    "connect_error": raiser(httpx.ConnectError),
    "read_timeout": raiser(httpx.ReadTimeout),
    "read_error": raiser(httpx.ReadError),
    "http_500": lambda r: httpx.Response(500, text="boom"),
}


def ocr_reply(*texts):
    return lambda request: httpx.Response(200, json={"data": [{"text": t} for t in texts]})


# ---- docker / auto 成功 -----------------------------------------------------

@pytest.mark.parametrize("mode", ["docker", "auto"])
async def test_success_returns_words_without_reason(upstream, make_ocr_service, mode):
    upstream.on(OCR_BASE, ocr_reply("apple", "Book"))
    words, reason = await make_ocr_service(mode).recognize(tiny_png())

    assert words == ["apple", "Book"]
    assert reason is None
    [request] = upstream.calls(OCR_BASE)
    assert request.url.path == "/ocr"
    assert b'filename="image.jpg"' in request.content


async def test_words_are_cleaned(upstream, make_ocr_service):
    upstream.on(OCR_BASE, ocr_reply("  Apple ", "apple", "123", "", "   ", "!!", "APPLE", "it's", "Book"))
    words, _ = await make_ocr_service("docker").recognize(tiny_png())
    # 去首尾空白、丢弃不含字母的项、不区分大小写去重并保留首次出现的写法
    assert words == ["Apple", "it's", "Book"]


async def test_missing_data_field_returns_empty_list(upstream, make_ocr_service):
    upstream.on(OCR_BASE, lambda r: httpx.Response(200, json={"code": 0}))
    words, reason = await make_ocr_service("docker").recognize(tiny_png())
    assert words == [] and reason is None


# ---- docker 失败 → 抛错；auto 失败 → 回落 mock ------------------------------

@pytest.mark.parametrize("case", FAILURES)
async def test_docker_mode_failure_raises(upstream, make_ocr_service, case):
    upstream.on(OCR_BASE, FAILURES[case])
    with pytest.raises(OCRServiceError) as exc:
        await make_ocr_service("docker").recognize(tiny_png())
    assert str(exc.value) == "ocr_unavailable"


@pytest.mark.parametrize("case", FAILURES)
async def test_auto_mode_failure_falls_back(upstream, make_ocr_service, case):
    upstream.on(OCR_BASE, FAILURES[case])
    words, reason = await make_ocr_service("auto").recognize(tiny_png())
    assert words == MOCK_FIRST_THREE
    assert reason == "ocr_unavailable"


# ---- mock -------------------------------------------------------------------

@pytest.mark.parametrize("image", [tiny_png(), b"not an image"])
async def test_mock_mode_never_calls_ocr(upstream, make_ocr_service, image):
    words, reason = await make_ocr_service("mock").recognize(image)
    assert words == MOCK_FIRST_THREE
    assert reason == "ocr_mock"
    assert upstream.requests == []
