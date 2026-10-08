# syntax=docker/dockerfile:1
# 后端镜像（E-2）。构建：在 docker/ 下 docker compose build backend

ARG PYTHON_IMAGE=python:3.13.4-slim-bookworm

# ---- 构建阶段：运行时依赖装进独立 venv ----
FROM ${PYTHON_IMAGE} AS builder
# 国内网络可在构建时传 --build-arg PIP_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple
ARG PIP_INDEX_URL=https://pypi.org/simple
ENV PIP_NO_CACHE_DIR=1 PIP_DISABLE_PIP_VERSION_CHECK=1
RUN python -m venv /opt/venv
ENV PATH=/opt/venv/bin:$PATH
COPY requirements.txt .
RUN pip install --index-url "$PIP_INDEX_URL" -r requirements.txt \
 && pip uninstall -y pip

# ---- 运行阶段 ----
FROM ${PYTHON_IMAGE}
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH=/opt/venv/bin:$PATH
RUN groupadd --system --gid 10001 app \
 && useradd --system --uid 10001 --gid app --no-create-home --shell /usr/sbin/nologin app
WORKDIR /app
COPY --from=builder /opt/venv /opt/venv
# 只复制 .dockerignore 放行的文件；归 root 所有，app 用户只读
COPY . .
USER app
EXPOSE 8000
# /health 不访问数据库；镜像里没有 curl，用 Python 标准库检查
HEALTHCHECK --interval=15s --timeout=5s --start-period=40s --retries=3 \
  CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=3)"]
# 先迁移再启动：迁移失败时容器退出，不带着旧表结构提供服务；exec 让 uvicorn 成为 1 号进程。
# 1 个 worker（会话清理任务按进程运行）；--no-proxy-headers：不信任 X-Forwarded-For（S-5）
CMD ["sh", "-c", "alembic upgrade head && exec uvicorn main:app --host 0.0.0.0 --port 8000 --no-proxy-headers"]
