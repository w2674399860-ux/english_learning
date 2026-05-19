# 使用 Python 3.9 稳定版
FROM python:3.9-slim-bookworm

WORKDIR /app

# 1. 换源并安装基础系统依赖 (OpenCV 所需)
RUN sed -i 's/deb.debian.org/mirrors.cloud.tencent.com/g' /etc/apt/sources.list.d/debian.sources && \
    apt-get update && apt-get install -y --no-install-recommends \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# 2. 安装 RapidOCR 和 Web 依赖 (不再需要 paddlepaddle!)
RUN pip install --no-cache-dir \
    rapidocr_onnxruntime \
    fastapi \
    uvicorn \
    python-multipart \
    opencv-python-headless \
    -i https://pypi.tuna.tsinghua.edu.cn/simple

# 3. 复制代码
COPY server.py /app/server.py

# 4. 暴露端口并启动
EXPOSE 8866
CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8866"]