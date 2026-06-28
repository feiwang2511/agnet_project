# 拍照识别功能 - EVALUATE

## 任务信息

- Task ID: `recognize`
- Profile: `feature`
- 当前阶段: `EVALUATE`
- 日期: 2026-06-27

## 任务摘要

为错题本开发“拍照识别”能力：用户上传一道题目的图片后，后端调用 Bedrock Claude 识别题目内容，并返回可被前端、知识点归类和复习计划使用的结构化 JSON。

本阶段只确认任务理解、验收标准、风险和不可逆决策，不设计具体代码结构，也不实现业务代码。

## 用户目标

家长希望用拍照替代手工抄题，快速得到题目文本、知识点、置信度和是否需要确认的判断，从而让错题进入可检索、可复习的学习链路。

## Scope

本任务覆盖：

- 识别接口的输入输出契约。
- 图片输入的基础校验。
- Bedrock Claude 识别调用的业务边界。
- 识别结果 schema 校验。
- 低置信度进入待确认。
- Bedrock 异常和超时处理。
- 不泄漏凭证和用户图片内容。
- 与上述行为对应的测试和验证要求。

本任务不覆盖：

- 前端拍照 UI 的完整实现。
- DynamoDB 持久化设计。
- 复习计划生成算法。
- 识别准确率模型评测体系。
- 用户认证和权限模型。

## Knowledge 引用

- `knowledge/PRODUCT.md`
  - BR-001: 已确认错题必须关联至少一个知识点。
  - BR-002: `confidence < 0.75` 必须标记待确认。
  - BR-004: AI 识别结果不能直接覆盖用户确认内容。
- `knowledge/TECH.md`
  - ADR-002: 使用 Bedrock Claude 而非自建模型。
  - ADR-003: 识别结果采用 schema-first 契约。
  - `POST /recognize` 接口契约。
- `knowledge/IMPROVEMENT.md`
  - 优先级：识别结果可靠性优先于流程跑通。
  - 禁止事项：不能绕过 schema 校验，不能泄漏凭证或用户图片内容。
- `governance/principles.md`
  - P1: 完成 = 主动验证且没有失败项。
  - P2: 宁可进入待确认，也不让脏数据进入正式学习链路。
  - P3: 不可逆决策必须留下理由和代价。
  - P4: 契约和命名必须让陌生人秒懂意图。
- `governance/rules/R001-schema-completeness.md`
- `governance/rules/R002-confidence-gating.md`
- `governance/rules/R003-no-secret-or-private-data-leak.md`

## 验收标准（Acceptance Criteria）

### AC-001: 接口能接收题目图片请求

- Given 请求包含一张非空图片、学科和年级
- When 调用 `POST /recognize`
- Then 系统进入识别流程
- And 不因缺少可选字段而失败

判定方式：接口测试覆盖合法图片输入，返回结构化响应或明确业务错误。

### AC-002: 非法图片输入被客户端错误阻断

- Given 图片为空、格式不支持或超过大小限制
- When 调用 `POST /recognize`
- Then 返回可判定的客户端错误
- And 不调用 Bedrock
- And 不写入正式识别结果

判定方式：测试用例能证明 invalid image 分支不会触发 Bedrock provider。

### AC-003: 成功识别响应必须满足完整 schema

- Given Bedrock 返回可解析识别结果
- When 后端生成响应
- Then JSON 必须包含：
  - `question_text: string`
  - `answer: string | null`
  - `knowledge_points: string[]`
  - `confidence: number`
  - `status: "confirmed" | "needs_confirmation"`
  - `raw_model_output_id: string`
- And `confidence` 必须在 `[0, 1]`
- And `question_text` 必须是非空字符串

判定方式：schema 测试覆盖字段存在、类型、范围和非空约束。

### AC-004: 低置信度结果必须进入待确认

- Given 识别结果 `confidence < 0.75`
- When 系统返回识别结果
- Then `status = "needs_confirmation"`
- And 不自动生成正式复习计划
- And 不更新最终掌握状态

判定方式：测试覆盖 `confidence = 0.74`，断言状态为 `needs_confirmation`。

### AC-005: 高置信度结果也必须经过 schema 校验

- Given 识别结果 `confidence >= 0.75`
- When 缺失核心字段或字段类型错误
- Then 系统不能返回成功状态
- And 不能把该结果写入正式学习链路

判定方式：测试覆盖高置信度但缺少 `question_text` 或 `knowledge_points` 的模型输出。

### AC-006: Bedrock 异常不能伪装成成功识别

- Given Bedrock 超时、限流、权限失败或返回不可解析内容
- When 调用 `POST /recognize`
- Then 系统返回可追踪错误
- And 响应中不能伪造 `question_text` 或 `confidence`
- And 日志包含脱敏 request id

判定方式：provider mock 抛出异常时，接口返回错误分支且没有成功 schema。

### AC-007: Bedrock SDK 细节不能泄漏到业务层

- Given 业务层需要识别图片
- When 调用识别能力
- Then 业务层依赖 provider 边界，而不是直接依赖 Bedrock SDK 响应结构

判定方式：PLAN 阶段必须定义 provider 边界；BUILD 阶段检查 handler 不直接解析 Bedrock SDK 原始对象。

### AC-008: 不得泄漏凭证或用户图片内容

- Given 处理识别请求时发生成功、失败或调试日志
- When 写入日志、测试 fixture 或文档
- Then 不能包含真实 API key、AWS 凭证、完整 base64 图片或可识别用户隐私数据

判定方式：基础 Gate 和 review 检查无明显 secrets；测试 fixture 使用合成数据。

### AC-009: 完成前必须有测试和主动验证记录

- Given BUILD 已完成
- When 进入 VERIFY
- Then 必须记录测试命令和结果
- And 至少包含 5 种主动破坏尝试
- And 所有 AC 有 pass/fail 标记

判定方式：`spec/recognize/verify.md` 满足 G4 条件后才能 Done。

## 风险清单

| 风险 | 影响 | 初步处理 |
| --- | --- | --- |
| Bedrock 返回自然语言而非 JSON | schema 校验失败或解析不稳定 | PLAN 阶段设计结构化提示词和解析失败处理 |
| 低置信度结果被误认为可用 | 污染知识点和复习计划 | 强制使用 `confidence < 0.75` gating |
| 高置信度但字段缺失 | 前端或复习链路崩溃 | schema-first，缺字段不能成功 |
| 图片过大导致延迟或成本上升 | 超过 5 秒体验目标，成本不可控 | PLAN 阶段定义大小限制和错误响应 |
| 日志泄漏图片或凭证 | 隐私和安全风险 | 日志只记录脱敏 request id |
| 业务层耦合 Bedrock SDK | 后续替换 provider 成本高 | PLAN 阶段定义 provider 边界 |

## 不可逆决策声明

当前 EVALUATE 阶段不新增 ADR，但任务涉及以下已存在的不可逆决策：

- ADR-002: 使用 Bedrock Claude 而非自建模型。
- ADR-003: 识别结果采用 schema-first 契约。

PLAN 阶段如果做出以下决定，必须新增或更新 ADR：

- 固化新的 `POST /recognize` 响应字段。
- 决定识别结果是否直接写入 DynamoDB。
- 决定具体 Bedrock model id 或 provider 抽象边界。
- 改变 `confidence < 0.75` 的业务阈值。

## 待确认问题

这些问题不阻塞 G1，但必须在 PLAN 阶段给出保守默认或请求用户确认：

1. 图片大小上限是多少？建议 PLAN 阶段先用 10 MB 作为后端上限，并写明理由。
2. 支持哪些图片格式？建议先支持 JPEG 和 PNG。
3. `subject` 和 `grade` 是必填还是可选？建议先允许可选，但有值时传入识别上下文。
4. 是否在识别接口中写入数据库？建议本轮先只返回结构化结果，不做持久化。

## G1 自检

- [x] `spec/recognize/evaluate.md` 存在。
- [x] 任务摘要和用户目标一致。
- [x] feature 任务有 3 条以上可判定 AC。
- [x] 已列出相关 Knowledge 引用。
- [x] 已声明是否存在不可逆决策。
- [x] 有歧义时已记录待确认问题。

## G1 结论

EVALUATE artifact 满足 G1 条件，可以进入 PLAN 阶段。

