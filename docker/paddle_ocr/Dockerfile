# 1. 明确指定使用 bookworm (Debian 12 稳定版)
FROM python:3.9-slim-bookworm

# 2. 设置工作目录
WORKDIR /app

# =========================================================================
# 3. 换成【阿里云源】
RUN sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources && \
    sed -i 's/security.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources
# =========================================================================

# 4. 安装依赖库（增加了 libgomp1）
RUN apt-get update && apt-get install -y --no-install-recommends --fix-missing \
    libgl1 \
    libglib2.0-0 \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# 5. 安装 Python 依赖包 (pip 安装使用清华源)
RUN pip install --no-cache-dir \
    paddlepaddle \
    paddleocr \
    fastapi \
    uvicorn \
    python-multipart \
    -i https://pypi.tuna.tsinghua.edu.cn/simple

# 6. 复制代码
COPY server.py /app/server.py

# 7. 暴露端口并启动
EXPOSE 8000
CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8000"]