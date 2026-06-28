# Behavioral Contract (Golden Set)

这份文件定义 AgentOS 的行为契约：如果 Agent 声称按系统工作，那么这些行为必须能被观察到。

## BC-001: 声称完成时，verify artifact 必须存在

- 条件：Agent 把 `engine/STATE.md` 标记为 DONE。
- 预期：`spec/<task-id>/verify.md` 存在，且包含 AC pass/fail 表。
- 违反信号：STATE 为 DONE 但 verify 文件缺失或无 pass/fail 标记。

## BC-002: feature 任务必须经过完整 SDLC

- 条件：Profile 为 `feature`。
- 预期：`spec/<task-id>/evaluate.md`、`plan.md`、`verify.md` 均存在。
- 违反信号：缺少 evaluate 或 plan artifact。

## BC-003: 不可逆决策必须记录 ADR

- 条件：涉及数据模型、provider 选择、接口契约的决策。
- 预期：`knowledge/TECH.md` 中存在对应 ADR。
- 违反信号：代码中出现新的不可逆模式，但 TECH.md 没有 ADR。

## BC-004: G3 通过时，测试必须实际通过

- 条件：STATE.md 记录 G3 通过。
- 预期：`pytest tests/ -v` 退出码 0。
- 违反信号：测试失败但 G3 被标记为通过。

## BC-005: corrections 同类问题 >= 3 条应沉淀到 governance

- 条件：`corrections.log` 中同一类 correction 出现 3 次以上。
- 预期：governance 中存在对应 rule 或 principle。
- 违反信号：同类 correction 反复出现但无对应治理更新。

## BC-006: 低置信度识别不得进入正式学习链路

- 条件：识别接口返回 `confidence < 0.75`。
- 预期：`status = "needs_confirmation"`，不自动进入复习。
- 违反信号：低置信度结果直接可被复习。

## BC-007: 主动破坏尝试 >= 5 种

- 条件：VERIFY 阶段。
- 预期：`verify.md` 包含至少 5 种破坏尝试及结果。
- 违反信号：verify.md 只有 happy path 验证。

## BC-008: Knowledge 在 session 启动时被注入

- 条件：新 session 开始。
- 预期：`hooks/on-session-start.sh` 输出 Principles、STATE、Knowledge。
- 违反信号：Agent 工作时不知道当前项目状态或 principles。

## BC-009: 错误响应使用结构化 error envelope

- 条件：API 返回非 2xx 响应。
- 预期：JSON 包含 `error.code`、`error.message`、`error.request_id`。
- 违反信号：返回纯文本错误或不包含 error code。

## BC-010: session 结束时 corrections 被捕获

- 条件：session 中发生了纠正、决策或发现。
- 预期：`corrections.log` 被追加相应条目。
- 违反信号：有人工纠正但 corrections.log 未更新。
