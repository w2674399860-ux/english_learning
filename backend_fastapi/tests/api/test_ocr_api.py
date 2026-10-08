"""POST /api/v1/ocr/recognize：三种模式下的成功与失败、上传校验。"""
import httpx
import pytest
from conftest import OCR_BASE, raiser, tiny_png

URL = "/api/v1/ocr/recognize"
OCR_DETAIL = "识别服务暂时不可用，请稍后再试"

FAILURES = {
    "connect_error": raiser(httpx.ConnectError),
    "read_timeout": raiser(httpx.ReadTimeout),
    "read_error": raiser(httpx.ReadError),
    "http_500": lambda r: httpx.Response(500),
}


def upload(client, content=None, content_type="image/png"):
    content = tiny_png() if content is None else content
    return client.post(URL, files={"file": ("photo.png", content, content_type)})


def ocr_ok(request):
    return httpx.Response(200, json={"data": [{"text": "apple"}, {"text": "Library"}]})


@pytest.mark.parametrize("mode", ["docker", "auto"])
def test_success(client, upstream, use_ocr, mode):
    use_ocr(mode)
    upstream.on(OCR_BASE, ocr_ok)
    resp = upload(client)
    assert resp.status_code == 200
    assert resp.json() == {"words": ["apple", "Library"], "degraded": False, "reason": None}


@pytest.mark.parametrize("case", FAILURES)
def test_docker_mode_failure_is_503(client, upstream, use_ocr, case):
    use_ocr("docker")
    upstream.on(OCR_BASE, FAILURES[case])
    resp = upload(client)
    assert resp.status_code == 503
    assert resp.json() == {"detail": OCR_DETAIL}


@pytest.mark.parametrize("case", FAILURES)
def test_auto_mode_failure_degrades(client, upstream, use_ocr, case):
    use_ocr("auto")
    upstream.on(OCR_BASE, FAILURES[case])
    resp = upload(client)
    assert resp.status_code == 200
    assert resp.json() == {"words": ["apple", "book", "cat"], "degraded": True, "reason": "ocr_unavailable"}


def test_mock_mode(client, upstream, use_ocr):
    use_ocr("mock")
    resp = upload(client)
    assert resp.status_code == 200
    assert resp.json() == {"words": ["apple", "book", "cat"], "degraded": True, "reason": "ocr_mock"}
    assert upstream.requests == []


@pytest.mark.parametrize("content_type", ["text/plain", "application/pdf", "application/octet-stream"])
def test_non_image_is_400(client, upstream, use_ocr, content_type):
    use_ocr("docker")
    resp = upload(client, b"hello", content_type)
    assert resp.status_code == 400
    assert resp.json() == {"detail": "只能上传图片文件"}
    assert upstream.requests == []


def test_missing_file_is_422(client, upstream, use_ocr):
    use_ocr("docker")
    resp = client.post(URL)
    assert resp.status_code == 422
    assert upstream.requests == []
