# CLAUDE.md — AI English Learning App（第二阶段）

> 给 Claude Code 的项目说明与工作约定。**当前做「第二阶段」**：E-4、U-4 / A-3、A-1、U-6、U-8。
> 依据：《项目架构分析报告.md》《问题清单与改进建议.md》（基于提交 `cacae4b`，2026-09-24）。第一阶段已完成、已提交并经手动验证。
> 报告是**分析结论，不是事实本身**。第一阶段已改动过前端，报告里的行号很可能已经偏移，动手前一律以代码为准；与报告不符时停下来报告，不要按报告硬改。

---

## 1. 项目速览

拍照 → OCR 提取单词 → **用户在确认页勾选 / 增删单词** → AI 生成短文与中译 → 生成中英文填空 → 存档 / 收藏 / 导出 PDF。

| 层 | 技术 | 位置 |
|----|------|------|
| 前端 | Flutter（Dart ^3.11.5）、Material 3、`provider`（单一 `AppProvider`）、`dio` | `frontend_flutter/lib/` |
| 后端 | FastAPI + Uvicorn，API → Service → Model 三层，SQLite（标准库 `sqlite3`） | `backend_fastapi/` |
| OCR | RapidOCR 独立容器（目录名仍叫 `paddle_ocr`） | `docker/paddle_ocr/` |
| AI | DeepSeek `deepseek-chat`，失败时降级为 mock | `backend_fastapi/app/services/ai_service.py` |

仓库根目录：`D:\all_project\English_Vocab02\english_learning_app`

### 第一阶段完成后的现状（开工前自行核对）

- 新增单词确认页 `lib/pages/words/word_confirm_page.dart`，勾选状态在 `AppProvider`；确认页的生成按钮兼任「重新生成」
- `recognizeText()` 只负责识别；由用户触发的生成入口最终走 `_generateStory()`，其内部**串行调用** `/story/generate` → `/story/fill-blank`
- `_isSaved` / `_saveError` 的复位写在 `_generateStory()` 内部；保存失败不写共享的 `_error`
- 公共组件：`lib/widgets/highlighted_text.dart`、`lib/widgets/save_button.dart`
- 前端 `receiveTimeout = 180000`；后端 DeepSeek 超时仍为 120 秒
- 已有测试：`validateNewWord`、`HighlightedText`、`SaveButton`（共 3 个文件）。**没有**确认页的 widget 测试，`AppProvider` 上也**没有** `@visibleForTesting` 注入方法（第二阶段开工核对结果）

以上是根据第一阶段汇报整理的，**若与代码或第一阶段版本的 CLAUDE.md 不一致，以代码为准并报告**。

## 2. 环境与命令

**只在本地运行。** 线上服务器已下线，在第三阶段完成前不会重新上线。

- 前端必须连本地后端。`api_config.dart` 中 `baseUrl` 现为 `String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8000')`（提交 `2a825bb` 引入），即默认连本地 8000，可用 `--dart-define=API_BASE_URL=...` 覆盖。本阶段不再改动这一配置方式与默认值。
- 真实 OCR 需要先启动 Docker 与 OCR 容器。Docker 未启动时，后端当前会返回 503（说明本地 `.env` 中的 OCR 模式不是 `auto`；`config.py` 与 `.env.example` 的默认值是 `auto`）。
- 本地后端统一使用 **8000** 端口，在 `backend_fastapi/` 下启动：

  ```
  python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
  ```

- **过时文档（收尾时处理，现在不改）**：`开发者操作文档.md` 与 `backend_fastapi/.env.example` 中写的是 8002 端口。
- 提交 `2a825bb` 带入的根目录 `test` 垃圾文件、`backend_fastapi/static/` 下重复的 NotoSansSC 字体，本阶段不动。

前端（在 `frontend_flutter/` 下）：

```
flutter pub get
flutter analyze
flutter test test/<具体文件>_test.dart
flutter run
```

**不要用无参 `flutter test` 判断整体是否通过**：模板遗留的 `widget_test.dart` 仍会失败，它属于第三阶段 E-3，本阶段不动。

**后端没有测试框架**，本阶段也不引入 pytest。后端改动的验证方式：

1. 通过 `http://localhost:8000/docs`（Swagger）或 `curl` 实际调用接口，汇报里贴出**命令与真实响应**
2. 纯函数（如 E-4 的解析函数）可以写**临时脚本**验证，跑完删除，不提交

## 3. 本阶段范围

**做：** E-4、U-4 / A-3、A-1、U-6、U-8（第 6 节有详细要求）。

**不做（发现问题只报告）：**

- A-1 的 SSE 流式输出（本阶段只合并接口）
- A-2 用户模型、A-4 SQLite 异步、A-5 拆分 Provider
- U-8 中的收藏与笔记
- U-9 原图回显、U-10 中文化、U-11 Web 体积
- T-1 ~ T-4、S-1 ~ S-4、E-1 ~ E-3、E-5
- 数据库表结构变更（例如把难度存进历史记录）
- 引入 pytest 或任何新依赖

### 公开发布门槛

项目目标是对外公开。S-1 路径穿越、S-2 无鉴权、S-3 CORS 全开与明文 HTTP、A-2 数据全局共享都在第三阶段。**本阶段完成仍不能上线**，阶段收尾汇报时必须重申。

## 4. 确认规则

**必须先停下、给方案、等我回复才能动手：**

1. **A-3 的配置设计**（环境区分方式、新增配置项名称与默认值、各失败场景的 HTTP 状态码）
2. **A-1 的接口设计**（请求 / 响应结构、错误与降级语义、超时预算，见第 9 节待确认项 1）
3. **U-8 历史分页与搜索的交互设计**
4. 任何数据库表结构变更、新增或升级依赖、拆分 `AppProvider`
5. 修改 `api_config.dart` 的 `baseUrl`，或任何 Docker / 部署配置
6. 删除任何现有接口
7. 报告说法与代码实际情况之间需要取舍的情形

**可以直接改（改完在汇报里说明）：** E-4、U-6、难度选择器，以及上面几项在我确认方案之后的实现细节。

**清单之外发现的问题：** 只记录，不修改。

## 5. 安全红线

- 不读取、不打印、不提交 `.env` 及任何密钥。需要改 `.env` 里的值时，告诉我改哪一项、改成什么，由我来改。可以修改 `config.py` 中的默认值，以及 `.env.example`（若存在）。
- 不执行破坏性 git 命令（`reset --hard`、`push --force`、`clean -fd`、`checkout .` 等）。
- 不自动提交。每完成一项，列出改动文件与建议的 commit message。
- 不删除 `backend_fastapi/data/` 下的数据库文件；需要干净数据时先问我。
- 不碰 `main.py` 的静态路由与 CORS（S-1 / S-3 属于第三阶段）；若改动必须经过 `main.py`，先问我。

## 6. 第二阶段任务

建议顺序：**E-4 → U-4 / A-3 → A-1 → U-6 → U-8**。

理由：E-4 最小，且它的"解析失败"会流入降级逻辑，而 A-3 正是重新定义降级；A-1 在加固过的 Service 之上合并接口，并把降级标记一起带出；U-6 的阶段划分取决于 A-1 之后的请求结构，所以放在 A-1 之后；U-8 的难度要经由新接口传递，放最后。

### E-4　AI 返回解析加固

- 现象：`ai_service.py` 直接 `json.loads(content)`，模型输出被 ` ```json ` 围栏包裹时抛 `JSONDecodeError`，且这一步在降级逻辑之外，会直接 500。
- 要求：
  1. 抽出一个纯函数：先剥离代码围栏，失败再用正则提取第一个 `{...}` 片段。
  2. 解析仍然失败时，**不要直接 500**，改为抛出一个可识别的解析异常，交给降级逻辑处理。本任务里降级逻辑保持现状；它在开发 / 生产环境下的行为由 A-3 决定。
  3. 解析成功后校验必需字段是否存在（如 `english` / `chinese`），缺失同样按解析失败处理。
  4. 把原先的 `print` 改为 `logging`，记录异常类型与内容摘要。**不要把 API Key 或完整请求头写进日志。**
- 验收：临时脚本覆盖以下输入并贴出结果——纯 JSON、` ```json ` 包裹、` ``` ` 包裹、JSON 前后带说明文字、非 JSON、缺字段。脚本跑完删除。

### U-4 / A-3　降级可见化与环境区分

**先出方案，等我确认（第 4 节第 1 条）。**

已决定的原则：**开发环境静默降级并加标记，生产环境直接报错。**

- 后端要求：
  1. 用配置区分环境。清单建议：OCR 沿用现有 `ocr_mode`（开发 `auto`、生产 `docker`），AI 侧新增对称的开关（清单建议名为 `ai_fallback_enabled`）。方案里说明你采用的方式；若认为应当改用统一的环境变量（如 `APP_ENV`），给出理由，由我决定。
  2. 默认值见第 9 节待确认项 2。
  3. 降级发生时，响应体带 `"degraded": true` 与 `"reason"`（如 `ocr_unavailable`、`ai_unavailable`、`ai_parse_failed`、`ai_not_configured`，最后一项见第 9 节待确认项 12）。未降级时要么不带、要么为 `false`，方案里统一定下来。
  4. 生产模式下失败直接返回错误。方案里列出每种失败对应的 HTTP 状态码与 `detail` 文案。
  5. 把 `ai_service.py` 中过宽的 `except Exception` 收窄：区分网络 / 超时、上游 HTTP 错误、E-4 的解析异常，分别记日志。
- 前端要求：
  1. 响应带 `degraded` 时，在对应页面顶部显示提示条：OCR 降级显示在确认页，AI 降级显示在 StoryPage。文案的语言见第 9 节待确认项 4。
  2. 生产模式下错误会变成常见路径。错误页面目前直接显示 Dio 的整段异常文本，见第 9 节待确认项 3。
  3. 降级的故事能否保存，见第 9 节待确认项 5。
  4. `_extractWords` / `_safeString` 等防御性解析要能处理新增的 `degraded` / `reason` 字段，不因多出字段而崩溃。
- 验收（每项贴出实际响应或截图说明）：
  - 开发配置 + Docker 关闭 → 确认页显示 mock 词表**并出现提示条**
  - 开发配置 + AI 不可用（例如临时把 DeepSeek 地址指向不可达地址，**由我改 `.env`**）→ StoryPage 出现提示条
  - 生产配置 + Docker 关闭 → 明确的错误提示，**没有** mock 词表
  - 生产配置 + AI 不可用 → 明确的错误提示，**没有** fox 故事
  - 一切正常 → 不出现提示条

### A-1　合并生成接口 `/learn/compose`

**先出方案，等我确认（第 4 节第 2 条）。**

- 已决定：新增 `/api/v1/learn/compose`，接收用户确认后的词表和难度，在后端串行完成"生成短文 → 生成填空"，一次返回；`/ocr/recognize` 保持独立。**不做 SSE 流式。**
- 要求：
  1. 请求：`{words, difficulty}`；响应至少包含 `english`、`chinese`、`english_blank`、`chinese_blank`，以及 A-3 定下的 `degraded` / `reason`。任一步降级都要体现在响应里。
  2. 放在新的路由文件中还是 `story.py` 中，方案里说明。编排逻辑放在 Service 层，路由只做参数校验。
  3. 前端 `_generateStory()` 改为只调用这一个接口。`_isSaved` 复位、`_error` 处理、确认页重试的行为**全部保持不变**。
  4. 旧接口 `/story/generate`、`/story/fill-blank`：**保留**，在代码与 Swagger 中标注废弃；前端不再调用。是否删除，在第二阶段收尾时再问我。
  5. **超时预算**：合并后一个请求里有两次 AI 调用，后端最坏情况约 2 × 120 = 240 秒，**超过前端的 180 秒**，会破坏第一阶段"前端超时大于后端"的约定。方案里必须给出解决办法，见第 9 节待确认项 1。
- 验收：Swagger 调用新接口的实际响应；前端完整走一遍"确认页 → 生成 → StoryPage → 保存 → 返回确认页重新生成"；实现后重新核对 `_currentRecord` 的写入点是否仍只有 `_generateStory()` 一处；说明前端实际发出的请求数（应从 2 个变为 1 个）。

### U-6　分阶段加载提示

- 现象：等待期间只有一个转圈加一句 `Analyzing image...`。
- 要求：
  1. 把 `AppProvider` 里与生成流程相关的 `_isLoading` 换成阶段枚举。**注意：** A-1 之后"写短文"和"挖空"合并在同一个请求里，没有流式输出时前端无法区分这两步。所以阶段只有两个：识别中、生成中。**不要**用计时器伪造第三个阶段。
  2. 识别阶段显示在 OcrPage，生成阶段显示在确认页（或当前实际的等待位置，按代码现状定）。
  3. 历史列表加载与生成流程共用 `_isLoading`，且历史加载 / 删除失败写共享的 `_error`：把历史的 loading 与 error 一起拆出来单独管理，不要让历史加载影响识别 / 生成页面；历史页只新增一个错误显示（见第 9 节待确认项 13）。
  4. 取消功能见第 9 节待确认项 6。
- 验收：widget 测试断言不同阶段显示不同文案（测抽出的无状态阶段 Widget，见第 9 节待确认项 11）；手动走一遍识别与生成，确认文案切换正确，失败后阶段复位。

### U-8　难度选择器 + 历史分页与搜索

**历史部分先出交互方案，等我确认（第 4 节第 3 条）。** 难度选择器可以直接做。

难度选择器：

- 放在确认页，三个 `ChoiceChip`：beginner / intermediate / advanced，默认 `intermediate`。
- 选中的难度经 A-1 的新接口传给后端，替换 `api_service.dart` 中写死的 `intermediate`。
- 难度状态放在 `AppProvider`，与词表一样在"返回确认页重新生成"时保留。
- 是否跨会话记住上次选择，见第 9 节待确认项 7。
- **不把难度存进历史记录**（需要改表结构，不在范围内）。

历史分页与搜索：

- 后端 `GET /history/records` 已支持 `page` / `page_size` / `search`，**后端不改**。开工前先读后端代码，说明 `search` 实际匹配哪些字段、返回结构里有没有总数。
- 方案需要说明：翻页方式（滚动到底自动加载 / "加载更多"按钮 / 页码），搜索框位置，是否防抖、防抖多久，搜索无结果的空状态，删除一条记录后列表如何刷新。
- 收藏与笔记不做。
- 验收：本地先造出超过 20 条记录（用接口或正常流程，**不要直接改数据库文件**），确认第 21 条以后可见；搜索命中、未命中、清空搜索三种情况都正确；删除后列表与分页状态正确。

## 7. Skills 使用

Skills 目录：`D:\all_project\English_Vocab02\english_learning_app\skills`（已加入 `.gitignore`）。需要用到时，先读对应目录里的 `SKILL.md`，再按其指引执行。

| Skill 目录 | 本阶段用法 |
|-----------|-----------|
| `superpowers-main` | **主流程**。A-3、A-1、U-8 历史部分走完整流程（方案 → 我确认 → 计划 → 实现 → 验证）；E-4、U-6、难度选择器用计划 + 验证 |
| `frontend-design-main` | 只用于降级提示条、难度选择器、历史搜索与分页的视觉和交互参考。产出一律是 Flutter Widget 与 Material 3，不写 HTML / CSS / React |
| `zh-readme`、`zh-docgen` | 本阶段**不使用**。收尾时只列出因接口与配置变化而过时的文档 |
| `skills`、`synced` | 本阶段不使用，除非我指定 |

**优先级：本文件的范围与确认规则高于任何 skill 的流程要求。** skill 若要求自动提交、写 spec 文件并提交、创建分支 / worktree 或扩大改动范围，以本文件为准，并告诉我冲突点。

## 8. 完成标准与汇报格式

开工前先记录基线：`git status`（工作区应当干净）、`git log -1`、`flutter analyze` 告警数、第一阶段新增测试是否全部通过、`baseUrl` 当前值、后端 `/health` 是否正常。

每项任务完成时按下面格式汇报：

1. **改了什么**：文件列表与一句话说明
2. **验证结果**：`flutter analyze`（与基线对比）、跑了哪些测试、后端接口调用的**实际命令与响应**、手动验证了哪些路径
3. **未验证的部分**及原因
4. **与报告不符之处**
5. **清单外发现**：只记录，不修改
6. **需要我改的配置**：`.env` 中要新增或修改的项（只写键名和建议值，不写密钥）
7. **建议的 commit message**

阶段全部完成后，汇报末尾必须重申第 3 节的"公开发布门槛"。

## 9. 待确认项（当前默认处理，我回复后更新）

| # | 问题 | 当前默认 |
|---|------|---------|
| 1 | A-1 超时预算：合并后后端最坏约 240 秒，超过前端 180 秒。可选做法：① 后端 DeepSeek 单次超时降到 60 秒（第一阶段遗留的问题；U-4 让降级可见之后，再降的副作用小了很多）；② 前端把 compose 请求的超时单独提高；③ 给 compose 设一个总超时 | 在 A-1 方案中给出建议，由我决定；决定前不改任何超时值 |
| 2 | A-3 新配置项的默认值：默认"允许降级"对开发方便，默认"不允许降级"对上线安全 | 默认**不允许降级**（生产安全）；本地开发由我在 `.env` 中打开 |
| 3 | 错误页面目前显示 Dio 的整段英文异常。是否改为优先显示后端 `detail`、原始异常只写日志？ | 做，范围仅限错误文案的来源，不改错误页面布局 |
| 4 | 降级提示条与新增错误文案用中文还是英文？现有界面全英文，中文化是 U-10 | 跟随现有界面用英文，U-10 时统一处理 |
| 5 | 降级产出的故事能否保存进历史？数据库没有 `degraded` 字段，存进去后无法区分真假 | 允许保存，不做限制（降级只会出现在开发环境） |
| 6 | U-6 是否加"取消"按钮（Dio `CancelToken`）？ | 不做，只做阶段提示 |
| 7 | 难度是否跨会话记住（`shared_preferences`，依赖已装）？ | 不记住，每次启动默认 `intermediate` |
| 8 | 旧接口 `/story/generate`、`/story/fill-blank` 何时删除 | 本阶段保留并标注废弃，收尾时再问我 |
| 9 | 本地后端端口：文档与 `.env.example` 为 8002，`baseUrl` 默认值与 `config.py` 为 8000 | **已决定**：统一用 8000，启动命令见第 2 节；写 8002 的文档列为过时文档，收尾时处理 |
| 10 | 提交 `2a825bb` 带入的内容（根目录 `test` 垃圾文件、`backend_fastapi/static/` 下重复字体、`--dart-define` 改动） | **已决定**：本阶段不动 |
| 11 | U-6 的 widget 测试手段（`AppProvider` 没有测试注入入口，也不注入 `ApiService`） | **已决定**：把阶段视图抽成接收 `phase` 参数的无状态 Widget，直接测它；**不在 `AppProvider` 上加测试入口** |
| 12 | 未配置 API Key 时 `ai_service.py` 直接返回 mock，不经过异常分支 | **已决定**：单列 reason `ai_not_configured`。生产模式报错；开发模式且降级开关打开时降级并带该 reason，保证没有 API Key 也能跑通流程。写进 A-3 方案 |
| 13 | 历史加载 / 删除失败写共享的 `_error`，历史页也不显示错误 | **已决定**：在 U-6 中把历史的 loading 与 error **一起**拆出来，范围仅限这两个状态；历史页只新增一个错误显示，不做其他界面改动 |
| 14 | superpowers 的 brainstorming / writing-plans 会把 spec 与 plan 写入 `docs/superpowers/` 并提交 | **已决定**：spec 与 plan 只在对话里给出，不写文件、不提交 |
