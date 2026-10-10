# AI 英语学习

> 拍一张课本、单词表或试卷的照片，自动提取英文单词，由 AI 写成一篇包含这些单词的短文，附中文翻译和中英文填空练习，可以保存、搜索、导出 PDF 打印。

**适合谁用**：自学英语、想把零散生词变成阅读材料的个人；或者自己部署一份，给家人、小班级使用。界面为简体中文，学习内容（短文、单词、填空）为英文。

**当前状态**：三个开发阶段已完成，可以在本地或 Docker 中完整运行。代码层面具备对外开放的条件，但**还没有上线**：上线前必须先完成 HTTPS 等部署工作，见 [上线前清单](#上线前)。

## 功能

- **拍照识词**：拍照或从相册选图，OCR 提取英文单词
- **确认单词**：勾选、删除、手动添加单词（一次最多 20 个），选择难度（初级 / 中级 / 高级）
- **生成练习**：一次请求得到英文短文、中文翻译、英文填空、中文填空，目标单词高亮
- **历史记录**：保存、按单词或英文短文搜索、加载更多、删除，详情页导出 PDF
- **账号**：用户名 + 密码注册登录，每个人只能看到自己的记录；忘记密码由管理员重置
- **防滥用**：识别、生成按用户限次，登录、注册按 IP 限次，输入有大小上限

## 技术栈

| 层 | 技术 |
|---|---|
| 客户端 | Flutter 3.41（Dart 3.11），Material 3，`provider`，`dio`；Android / iOS / Web |
| 后端 | FastAPI + Uvicorn，Python 3.13，SQLAlchemy 2.0 异步 + Alembic |
| 数据库 | MySQL 8.4（Docker 容器） |
| OCR | **RapidOCR**（ONNX Runtime）独立容器。目录和服务名仍叫 `paddle_ocr`，是历史遗留，实际不使用 PaddleOCR |
| AI | DeepSeek `deepseek-chat` |

## 快速开始（本地开发，Windows PowerShell）

前置条件：Docker Desktop、Python 3.13、Flutter 3.41。

> ⚠️ 数据库容器使用主机端口 **3307**。如果本机另装了 MySQL 占用 3306，不要把连接串指向 3306，后端也会拒绝连接本机 3306。

**1. 准备配置**（在仓库根目录）

```powershell
Copy-Item docker\.env.example docker\.env
Copy-Item backend_fastapi\.env.example backend_fastapi\.env
```

编辑两份 `.env`：

- `docker/.env`：设置 `MYSQL_ROOT_PASSWORD`、`MYSQL_APP_PASSWORD`
- `backend_fastapi/.env`：把 `DATABASE_URL`、`TEST_DATABASE_URL` 中的 `change_me_app` 换成上面的应用账号密码；填 `DEEPSEEK_API_KEY`
- 本地开发建议设置 `OCR_MODE=auto`、`AI_FALLBACK_ENABLED=true`、`API_DOCS_ENABLED=true`：OCR 或 AI 不可用时返回示例数据，并在界面上标明

**2. 启动 MySQL 与 OCR 容器**

```powershell
cd docker
docker compose up -d mysql paddle_ocr
cd ..
```

MySQL 首次启动时会自动建开发库 `english_learning`、测试库 `english_learning_test` 和应用账号。OCR 镜像首次构建需要几分钟。

**3. 安装后端依赖并执行迁移**

```powershell
cd backend_fastapi
py -3.13 -m venv venv
venv\Scripts\python -m pip install -r requirements-dev.txt
venv\Scripts\python -m alembic upgrade head
venv\Scripts\python -m alembic -x target=test upgrade head
```

**4. 启动后端**（有系统代理时必须设置 `NO_PROXY`，写在 `.env` 里无效）

```powershell
$env:NO_PROXY = 'localhost,127.0.0.1'
venv\Scripts\python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload --no-proxy-headers
```

检查：`http://localhost:8000/health` 返回 `{"status":"ok","version":"1.0.0"}`。

**5. 启动前端**（另开一个终端）

```powershell
cd frontend_flutter
flutter pub get
flutter run -d chrome --web-port 5000
```

Web 调试需要在 `backend_fastapi/.env` 中设置 `CORS_ALLOW_ORIGINS=http://localhost:5000,http://127.0.0.1:5000`。Android 模拟器用 `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000`。

打开后先注册一个账号即可使用。

**或者：由后端直接托管 Web 页面**（同源，不需要 CORS）

```powershell
powershell -ExecutionPolicy Bypass -File scripts\build_web.ps1
```

脚本会构建 Flutter Web，并复制到 `backend_fastapi/static/`。之后访问 `http://localhost:8000/`。

## Docker 部署（后端、MySQL、OCR 全部容器化）

```powershell
powershell -ExecutionPolicy Bypass -File scripts\build_web.ps1
cd docker
docker compose up -d --build
```

- 后端容器读取 `backend_fastapi/.env`（运行时注入，不进镜像）。数据库地址、OCR 地址、生产模式开关由 compose 覆盖为容器内的值
- 后端启动时自动执行 `alembic upgrade head`，以非 root 用户运行
- 数据在命名卷 `english_learning_mysql_data` 中，`docker compose down` 后再 `up` 不会丢失

## 端口

| 服务 | 端口 | 说明 |
|---|---|---|
| 后端（API + Web 页面） | 8000 | |
| MySQL 8.4 | 3307（主机）→ 3306（容器内） | 只绑定 127.0.0.1 |
| OCR | 8866 | 只绑定 127.0.0.1，客户端不直接访问 |
| Flutter Web 调试 | 5000 | 固定端口，与 CORS 白名单对应 |

## 常用命令

```powershell
# 后端测试（backend_fastapi\ 下；需要 MySQL 容器在运行，只连测试库）
venv\Scripts\python -m pytest

# 前端检查与测试（frontend_flutter\ 下）
flutter analyze
flutter test

# 构建 Web 并由后端托管（仓库根目录）
powershell -ExecutionPolicy Bypass -File scripts\build_web.ps1

# 管理员：列出用户、重置密码、停用 / 启用账号（backend_fastapi\ 下）
venv\Scripts\python -m scripts.admin list-users
venv\Scripts\python -m scripts.admin reset-password <用户名>
venv\Scripts\python -m scripts.admin disable <用户名>
```

## 项目结构

```
english_learning_app/
├── backend_fastapi/        FastAPI 后端：app/（api、auth、ratelimit、services、models、db）、alembic/ 迁移、scripts/admin.py、tests/
├── frontend_flutter/       Flutter 客户端：lib/（pages、widgets、providers、auth、l10n、theme）、test/
├── docker/                 docker-compose.yml、MySQL 初始化脚本、OCR 服务（paddle_ocr/，实为 RapidOCR）
├── scripts/build_web.ps1   构建 Flutter Web 并放进 backend_fastapi/static/（static/ 不入版本库）
├── docs/                   开发者文档、架构说明、接口清单、各阶段审查
└── ui设计/                 Stitch 导出的 UI 设计稿（只作参考）
```

## 文档

| 文档 | 内容 |
|---|---|
| [开发者操作文档](docs/开发者操作文档.md) | 环境搭建、配置项、数据库与迁移、账号与限流、测试、构建部署、常见问题 |
| [系统架构说明](docs/系统架构说明.md) | 部署拓扑、代码分层、数据模型、页面流转、关键机制 |
| [后端接口清单](docs/后端接口清单.md) | 每个接口的请求、响应、错误码与中文文案 |
| [数据库设计方案](docs/数据库设计方案.md) | 表设计的取舍（最终结构以 Alembic 迁移为准） |
| [第三阶段收尾审查](docs/第三阶段收尾审查.md) | 安全总览、测试、遗留事项、上线前清单 |

## 上线前

本项目目前只在本地运行。对外开放前至少需要完成：

- **HTTPS**（域名、反向代理、证书）。有了账号体系后，密码和登录凭证走明文 HTTP 等于公开
- 后端端口只绑定本机，由反向代理转发；配置反向代理传递客户端真实 IP（否则登录、注册限流全站共用一个额度）
- MySQL 迁移账号与运行账号分开；数据库每日备份
- 替换授权不明的占位插画（见 `frontend_flutter/assets/images/SOURCES.md`）
- 隐私政策、用户协议

完整清单见 [第三阶段收尾审查第 10 节](docs/第三阶段收尾审查.md#10-上线前清单claudemd-第-10-节)。

## License

待补充。字体为 SIL OFL 1.1（随 App 分发许可证文本）；插画为占位素材，授权不明。
