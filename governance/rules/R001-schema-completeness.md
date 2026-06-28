# Rule: 识别接口必须返回完整 schema

## 追溯

- Principle: P2（宁可进入待确认，也不让脏数据进入正式学习链路）
- Knowledge: `knowledge/TECH.md` 的 ADR-003 schema-first 契约
- Product Rule: `knowledge/PRODUCT.md` 的 BR-001 和 BR-002

## 判定标准

识别接口返回成功结果时，JSON 必须包含：

- `question_text: string`，非空。
- `knowledge_points: string[]`，可以为空数组，但字段必须存在。
- `confidence: number`，范围为 `[0, 1]`。
- `status: "confirmed" | "needs_confirmation"`。
- `raw_model_output_id: string`，用于追踪模型调用。

如果任一核心字段缺失，不能返回成功状态。

## 反例

- 只返回 AI 原始文本。
- 返回了题干但没有 `confidence`。
- `confidence` 是字符串 `"high"` 而不是 `[0, 1]` 内的数字。
- 缺少 `status`，导致前端无法判断是否需要确认。

## 过期条件

- 当 `ci/verify.sh` 或更完整的 schema gate 能自动阻断该问题后，此 rule 可移动到 `_retired/`。
- 或连续 30 天没有 schema 缺失 correction 时重新评估是否保留。

