import os
import logging
from tempfile import NamedTemporaryFile
from fastapi import FastAPI, File, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from rapidocr_onnxruntime import RapidOCR # 改用轻量化引擎

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

@app.post("/ocr")
async def ocr_recognize(file: UploadFile = File(...)):
    logger.info(f"收到文件: {file.filename}")
    ext = os.path.splitext(file.filename or "image.jpg")[1] or ".jpg"

    with NamedTemporaryFile(delete=False, suffix=ext) as tmp:
        tmp.write(await file.read())
        tmp_path = tmp.name

    try:
        # 执行识别，result 格式为 [[box, text, score], ...]
        result, elapse = engine(tmp_path)
        
        words_list = []
        if result:
            for line in result:
                text = line[1]
                words_list.append({"text": text})
        
        logger.info(f"识别成功: 找到 {len(words_list)} 个文本段，耗时: {elapse}s")
        
        # 同时返回 data 和 words 字段，完美兼容你的主后端
        return {
            "data": words_list,
            "words": words_list
        }
    except Exception as e:
        logger.error(f"OCR 识别失败: {e}")
        return {"data": [], "words": [], "error": str(e)}
    finally:
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)

@app.get("/health")
async def health():
    return {"status": "ok", "service": "rapid_ocr"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("server:app", host="0.0.0.0", port=8866)