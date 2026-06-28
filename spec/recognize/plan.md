# 拍照识别功能 - PLAN

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:test-driven-development before BUILD, then use superpowers:verification-before-completion before claiming done. This artifact is the Delivery Engine PLAN for `spec/recognize/evaluate.md`.

**Goal:** 设计一个可测试、可替换 provider、schema-first 的拍照识别后端能力。

**Architecture:** 使用 FastAPI 提供 `POST /recognize` 入口；API 层只负责请求/响应适配，业务层负责图片校验、provider 调用、schema 校验和 confidence gating，provider 层隔离 Bedrock Claude 细节。BUILD 阶段先用 fake provider 和单元测试跑通核心行为，再接入 Bedrock provider 边界。

**Tech Stack:** Python FastAPI, Pydantic-style schema models, pytest, AWS Bedrock Claude provider boundary.

---

## 任务信息

- Task ID: `recognize`
- Profile: `feature`
- 当前阶段: `PLAN`
- 日期: 2026-06-28
- 输入 artifact: `spec/recognize/evaluate.md`
- 输出 artifact: `spec/recognize/plan.md`

## PLAN 阶段结论

本轮 BUILD 应实现一个最小可验证的后端识别切片：

1. 接收图片识别请求。
2. 校验图片为空、格式和大小。
3. 通过 provider 边界调用识别能力。
4. 对 provider 输出做 schema 校验。
5. 根据 `confidence < 0.75` 设置 `needs_confirmation`。
6. 对 Bedrock/provider 异常返回结构化错误。
7. 避免日志、测试和文档泄漏凭证或完整图片内容。

本轮不做数据库持久化，不生成复习计划，不实现前端 UI。

## 保守默认决策

这些决策来自 EVALUATE 的待确认问题，用保守默认推进 PLAN：

| 问题 | PLAN 决策 | 理由 | 是否 ADR |
| --- | --- | --- | --- |
| 图片大小上限 | 解码后最大 10 MB | 足够覆盖普通拍照题目，能控制延迟和成本 | 否，可配置 |
| 图片格式 | 仅支持 JPEG 和 PNG | K12 拍照最常见，便于用 magic bytes 判定 | 否，可扩展 |
| `subject` / `grade` | 可选 | 没有学科年级也应能识别，有值时传给 provider 做上下文 | 否 |
| 是否写数据库 | 本轮不写库，只返回结构化结果 | 避免把识别能力和持久化/复习计划耦合 | 否 |
| 错误响应结构 | 使用结构化 error envelope | 前端需要稳定判断错误类型，属于接口契约 | 是，ADR-004 |

## ADR 更新

本 PLAN 新增接口契约决策：

- `knowledge/TECH.md` 新增 ADR-004: 识别接口错误采用结构化错误响应。

不新增以下 ADR：

- 图片大小上限和格式支持是可配置策略，不是不可逆架构决策。
- 本轮不写数据库是 scope 决策，不改变 ADR-001。
- Provider 边界沿用 ADR-002，不新增 provider ADR。
- 成功响应 schema 沿用 ADR-003，不改变字段。

## 文件结构规划

BUILD 阶段应创建以下业务代码和测试文件：

| 文件 | 类型 | 责任 |
| --- | --- | --- |
| `app/main.py` | Create | 创建 FastAPI app，挂载识别 router |
| `app/recognition/__init__.py` | Create | 识别模块包入口 |
| `app/recognition/models.py` | Create | 请求、响应、错误、provider result 的 schema 和常量 |
| `app/recognition/provider.py` | Create | 定义 `RecognitionProvider` 边界和 `FakeRecognitionProvider` 测试实现 |
| `app/recognition/bedrock_provider.py` | Create | Bedrock provider 适配层骨架；不在单元测试中调用真实 Bedrock |
| `app/recognition/service.py` | Create | 图片校验、provider 调用、schema 校验、confidence gating |
| `app/recognition/api.py` | Create | `POST /recognize` API adapter |
| `tests/recognition/test_service.py` | Create | 核心业务行为测试 |
| `tests/recognition/test_api.py` | Create | API 入口和错误响应测试 |
| `tests/recognition/test_security.py` | Create | secrets 和图片内容不进入日志/fixture 的检查 |

目录边界：

- `api.py` 不直接依赖 Bedrock SDK。
- `service.py` 只依赖 `RecognitionProvider` 抽象。
- `bedrock_provider.py` 是唯一允许接触 Bedrock SDK 细节的文件。
- 测试默认使用 fake provider，不访问网络、不访问 AWS。

## 数据契约

### 请求模型

```json
{
  "image": "base64-encoded-image",
  "subject": "math",
  "grade": "grade_7"
}
```

字段约束：

- `image` 必填，必须是 base64 字符串。
- `subject` 可选，非空时传给 provider。
- `grade` 可选，非空时传给 provider。

### 成功响应模型

```json
{
  "question_text": "string",
  "answer": "string | null",
  "knowledge_points": ["string"],
  "confidence": 0.82,
  "status": "confirmed | needs_confirmation",
  "raw_model_output_id": "string"
}
```

校验规则：

- `question_text` 必须非空。
- `knowledge_points` 必须存在；可以为空数组。
- `confidence` 必须是 `[0, 1]` 内的数字。
- `status` 只允许 `confirmed` 或 `needs_confirmation`。
- `raw_model_output_id` 必须存在，用于追踪 provider 调用。

### 错误响应模型

```json
{
  "error": {
    "code": "invalid_image",
    "message": "Image must be a non-empty JPEG or PNG under 10 MB.",
    "request_id": "req_..."
  }
}
```

错误码：

| code | HTTP | 场景 |
| --- | --- | --- |
| `invalid_image` | 400 | 图片为空、base64 无法解码、格式不支持、超过 10 MB |
| `recognition_unavailable` | 502 | Bedrock/provider 超时、限流、权限失败或不可用 |
| `invalid_model_output` | 502 | provider 返回缺字段、类型错误、confidence 越界或不可解析 |

安全约束：

- `message` 不包含完整 base64 图片。
- `request_id` 可追踪但不暴露凭证。
- 日志只记录 `request_id`、错误码和脱敏上下文。

## Provider 边界

业务层依赖以下抽象，而不是 Bedrock SDK 原始对象：

```text
RecognitionProvider.recognize(image_bytes, subject, grade, request_id) -> ProviderRecognitionResult
```

Provider result 必须包含：

- `question_text`
- `answer`
- `knowledge_points`
- `confidence`
- `raw_model_output_id`

Provider 失败时抛出业务可识别异常：

- `RecognitionProviderUnavailable`
- `InvalidModelOutput`

这两个异常由 service 转换成结构化错误响应。

## Confidence Gating

规则来源：`knowledge/PRODUCT.md` BR-002 和 `governance/rules/R002-confidence-gating.md`。

```text
if confidence < 0.75:
    status = "needs_confirmation"
else:
    status = "confirmed"
```

注意：

- 高置信度不跳过 schema 校验。
- 低置信度不是系统错误，而是业务状态。
- 本轮不自动生成复习计划，因此用测试断言 service 不暴露任何写库或复习计划动作。

## 错误处理策略

| 场景 | 处理 |
| --- | --- |
| image 为空 | 返回 `invalid_image`，不调用 provider |
| base64 无法解码 | 返回 `invalid_image`，不调用 provider |
| 非 JPEG/PNG | 返回 `invalid_image`，不调用 provider |
| 解码后超过 10 MB | 返回 `invalid_image`，不调用 provider |
| provider 超时/限流/权限失败 | 返回 `recognition_unavailable` |
| provider 返回自然语言或不可解析内容 | 返回 `invalid_model_output` |
| provider 返回缺失 `question_text` | 返回 `invalid_model_output` |
| provider 返回 `confidence = 1.2` | 返回 `invalid_model_output` |
| provider 返回 `confidence = 0.74` 且 schema 完整 | 返回成功响应，`status = needs_confirmation` |

## 测试策略

BUILD 阶段使用 TDD，先写失败测试，再实现最小代码。

### 单元测试

文件：`tests/recognition/test_service.py`

必须覆盖：

- 合法 JPEG 输入调用 provider。
- 空图片不调用 provider。
- 非 base64 不调用 provider。
- 非 JPEG/PNG 不调用 provider。
- 超过 10 MB 不调用 provider。
- schema 完整时返回成功响应。
- `confidence = 0.74` 返回 `needs_confirmation`。
- `confidence = 0.75` 返回 `confirmed`。
- 高置信度但缺少 `question_text` 返回 `invalid_model_output`。
- provider 异常返回 `recognition_unavailable`。

### API 测试

文件：`tests/recognition/test_api.py`

必须覆盖：

- `POST /recognize` 成功响应字段完整。
- invalid image 返回 400 和 `error.code = invalid_image`。
- provider unavailable 返回 502 和 `error.code = recognition_unavailable`。
- 响应不包含 provider SDK 原始对象。

### 安全测试

文件：`tests/recognition/test_security.py`

必须覆盖：

- 测试 fixture 不包含 `AKIA`、private key、`sk-` token 形态。
- 错误消息不包含完整 base64 图片。
- 日志测试只允许 request id 和错误码。

## AC 映射表

| AC | 实现点 | 验证点 |
| --- | --- | --- |
| AC-001 | `api.py` 接收 `POST /recognize`，`service.py` 调用 provider | API 成功测试 + service 合法 JPEG 测试 |
| AC-002 | `service.py` 在 provider 前做 image 校验 | invalid image 测试断言 fake provider 未被调用 |
| AC-003 | `models.py` 定义成功响应 schema，`service.py` 校验 provider result | schema 完整性测试 |
| AC-004 | `service.py` 根据 `confidence < 0.75` 设置状态 | `confidence = 0.74` 测试 |
| AC-005 | `service.py` 高置信度仍做 schema 校验 | `confidence = 0.9` 但缺字段测试 |
| AC-006 | `provider.py` 异常类型，`service.py` 转换为结构化错误 | provider exception 测试 |
| AC-007 | `service.py` 依赖 `RecognitionProvider`，Bedrock 细节只在 `bedrock_provider.py` | 代码 review + import 边界检查 |
| AC-008 | 日志和错误消息只使用脱敏 request id | security 测试 + basic quality gate |
| AC-009 | VERIFY 阶段记录测试命令和 5 种破坏尝试 | `spec/recognize/verify.md` G4 检查 |

## BUILD 任务拆分

### Task 1: Schema 和错误模型

**Files:**

- Create: `app/recognition/models.py`
- Test: `tests/recognition/test_service.py`

步骤：

- [ ] 写失败测试：provider 返回完整结果时，service 输出完整 schema。
- [ ] 实现请求、响应、错误和 provider result 模型。
- [ ] 运行 `pytest tests/recognition/test_service.py -v`。

### Task 2: 图片输入校验

**Files:**

- Modify: `app/recognition/service.py`
- Test: `tests/recognition/test_service.py`

步骤：

- [ ] 写失败测试：空图片、非 base64、非 JPEG/PNG、超过 10 MB 都不调用 provider。
- [ ] 实现 base64 解码、magic bytes、大小检查。
- [ ] 运行 `pytest tests/recognition/test_service.py -v`。

### Task 3: Provider 边界

**Files:**

- Create: `app/recognition/provider.py`
- Create: `app/recognition/bedrock_provider.py`
- Test: `tests/recognition/test_service.py`

步骤：

- [ ] 写失败测试：service 只依赖 fake provider。
- [ ] 定义 `RecognitionProvider` 抽象和 provider 异常。
- [ ] 创建 `BedrockRecognitionProvider` 骨架，不在测试中访问 AWS。
- [ ] 运行 `pytest tests/recognition/test_service.py -v`。

### Task 4: Confidence gating 和 schema-first

**Files:**

- Modify: `app/recognition/service.py`
- Test: `tests/recognition/test_service.py`

步骤：

- [ ] 写失败测试：`confidence = 0.74` -> `needs_confirmation`。
- [ ] 写失败测试：`confidence = 0.75` -> `confirmed`。
- [ ] 写失败测试：高置信度缺字段 -> `invalid_model_output`。
- [ ] 实现 schema 校验和 gating。
- [ ] 运行 `pytest tests/recognition/test_service.py -v`。

### Task 5: API adapter

**Files:**

- Create: `app/main.py`
- Create: `app/recognition/api.py`
- Test: `tests/recognition/test_api.py`

步骤：

- [ ] 写失败测试：`POST /recognize` 返回完整成功响应。
- [ ] 写失败测试：invalid image 返回 400。
- [ ] 写失败测试：provider unavailable 返回 502。
- [ ] 实现 FastAPI router 和错误映射。
- [ ] 运行 `pytest tests/recognition/test_api.py -v`。

### Task 6: 安全和日志保护

**Files:**

- Modify: `app/recognition/service.py`
- Create: `tests/recognition/test_security.py`

步骤：

- [ ] 写失败测试：错误消息不包含完整 base64 图片。
- [ ] 写失败测试：fixture 不包含明显 secrets pattern。
- [ ] 实现脱敏日志字段，只记录 request id 和 error code。
- [ ] 运行 `pytest tests/recognition/test_security.py -v`。
- [ ] 运行 `governance/gates/check-basic-quality.sh`。

## G2 Devil's Advocate Review

### 质疑 1: 现在设计 `POST /recognize` 会不会过早锁定 API？

结论：风险可接受。成功响应字段已经在 `knowledge/TECH.md` ADR-003 中存在，本 PLAN 没有新增成功字段。错误响应确实属于契约，所以新增 ADR-004。

### 质疑 2: 本轮不写数据库，会不会让“错题本”功能不完整？

结论：不完整但合理。本轮目标是识别能力切片，持久化和复习计划属于后续 feature。先把识别结果做成干净结构化输出，可以避免一开始就污染数据库。

### 质疑 3: 10 MB 上限是否武断？

结论：是保守默认，但不是不可逆。它写入 PLAN 而非 ADR，后续可以通过真实图片样本和延迟数据调整。

### 质疑 4: FastAPI/Pydantic 细节是否可能和当前版本不一致？

结论：BUILD 阶段写具体 FastAPI/Pydantic 代码前，必须按 AGENTS.md 使用 `ctx7` 查询当前官方文档，避免 API 细节过期。

### 质疑 5: Bedrock provider 骨架是否会让测试假通过？

结论：单元测试只证明业务边界和错误处理，不证明真实 Bedrock 可用。VERIFY 阶段必须单独记录 mock 验证和真实集成验证的边界；没有真实凭证时不能声称 Bedrock 集成已验证。

## G2 自检

- [x] `spec/recognize/plan.md` 存在。
- [x] 每条 AC 都映射到实现点和验证点。
- [x] 错误处理策略覆盖主要失败路径。
- [x] 测试策略明确，没有写“后面补测试”。
- [x] 新增错误响应契约已更新 `knowledge/TECH.md` ADR-004。
- [x] 没有违反 active rules。
- [x] devil's advocate review 没有发现致命缺陷。

## G2 结论

PLAN artifact 满足 G2 条件，可以进入 BUILD 阶段。

