import os
import logging
from tempfile import NamedTemporaryFile
from fastapi import FastAPI, File, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from rapidocr_onnxruntime import RapidOCR
import cv2
import numpy as np

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="RapidOCR Service")

# 开启跨域支持
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 初始化 RapidOCR (体积小，加载极快)
engine = RapidOCR()


def preprocess_image(image_path: str):  # -> Optional[str]
    """对图像做灰度 + 自适应阈值 + 去噪，返回预处理后的临时文件路径。"""
    img = cv2.imread(image_path, cv2.IMREAD_COLOR)
    if img is None:
        return None
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    # 自适应阈值 — 应对光照不均
    thresh = cv2.adaptiveThreshold(
        gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
        cv2.THRESH_BINARY, 11, 2,
    )
    # 去噪 — 去除干扰小点
    denoised = cv2.fastNlMeansDenoising(thresh, h=30)
    base, ext = os.path.splitext(image_path)
    pre_path = f"{base}_preprocessed{ext}"
    cv2.imwrite(pre_path, denoised)
    return pre_path


def merge_ocr_results(result_a, result_b) -> list:
    """合并两轮 OCR 结果：先取原图的所有条目，再将预处理图的新词追加到末尾。"""
    seen = set()
    merged = []

    for line in (result_a or []):
        text = line[1].strip()
        merged.append({"text": text})
        seen.add(text.lower())

    for line in (result_b or []):
        text = line[1].strip()
        if text.lower() not in seen:
            merged.append({"text": text})
            seen.add(text.lower())

    return merged


@app.post("/ocr")
async def ocr_recognize(file: UploadFile = File(...)):
    logger.info(f"收到文件: {file.filename}")
    ext = os.path.splitext(file.filename or "image.jpg")[1] or ".jpg"

    with NamedTemporaryFile(delete=False, suffix=ext) as tmp:
        tmp.write(await file.read())
        original_path = tmp.name

    pre_path = None
    try:
        # 第一轮：原图 OCR
        result_a, elapsed_a = engine(original_path)
        logger.info(f"原图 OCR: {len(result_a) if result_a else 0} 段, {elapsed_a}s")

        # 第二轮：预处理后 OCR
        pre_path = preprocess_image(original_path)
        result_b = None
        if pre_path:
            result_b, elapsed_b = engine(pre_path)
            logger.info(f"增强 OCR: {len(result_b) if result_b else 0} 段, {elapsed_b}s")

        # 合并两轮结果
        words_list = merge_ocr_results(result_a, result_b)
        logger.info(f"合并后共 {len(words_list)} 个单词")

        return {
            "data": words_list,
            "words": words_list,
        }
    except Exception as e:
        logger.error(f"OCR 识别失败: {e}")
        return {"data": [], "words": [], "error": str(e)}
    finally:
        for p in [original_path, pre_path] if pre_path else [original_path]:
            if p and os.path.exists(p):
                os.unlink(p)

@app.get("/health")
async def health():
    return {"status": "ok", "service": "rapid_ocr"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("server:app", host="0.0.0.0", port=8866)