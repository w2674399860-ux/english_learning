"""
PaddleOCR HTTP 服务
提供 /ocr 接口，供后端 FastAPI 调用进行图片文字识别
请求方式：POST multipart/form-data，字段名：file
返回格式：{"data": [{"text": "识别结果"}, ...]}
"""

import os
import uuid
import logging
from tempfile import NamedTemporaryFile

from fastapi import FastAPI, File, UploadFile
from paddleocr import PaddleOCR

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="PaddleOCR Service")

# 全局初始化（首次加载较慢，之后复用）
# 顺便帮你把警告里的参数也改了：use_angle_cls 改为 use_textline_orientation
ocr = PaddleOCR(use_textline_orientation=True, lang="en")


@app.post("/ocr")
async def ocr_recognize(file: UploadFile = File(...)):
    """接收图片，返回识别到的文本行"""
    ext = os.path.splitext(file.filename or "image.jpg")[1] or ".jpg"

    with NamedTemporaryFile(delete=False, suffix=ext) as tmp:
        tmp.write(await file.read())
        tmp_path = tmp.name

    try:
        result = ocr.ocr(tmp_path, cls=True)
        words = []
        if result and result[0]:
            for line in result[0]:
                text = line[1][0]  # (bbox, (text, confidence))
                words.append({"text": text})
        logger.info(f"识别到 {len(words)} 个文本段")
        return {"data": words}
    except Exception as e:
        logger.error(f"OCR 识别失败: {e}")
        return {"data": []}
    finally:
        os.unlink(tmp_path)


@app.get("/health")
async def health():
    return {"status": "ok", "service": "paddle_ocr"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("server:app", host="0.0.0.0", port=8866)
