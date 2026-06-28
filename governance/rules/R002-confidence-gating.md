# Rule: 低置信度识别必须进入待确认

## 追溯

- Principle: P2（宁可进入待确认，也不让脏数据进入正式学习链路）
- Product Rule: `knowledge/PRODUCT.md` 的 BR-002

## 判定标准

当识别结果满足 `confidence < 0.75` 时，系统必须：

- 设置 `status = "needs_confirmation"`。
- 不自动生成正式复习计划。
- 不把知识点判断写入最终掌握状态。
- 给前端提供用户确认入口所需的信息。

当 `confidence >= 0.75` 时，也不能跳过 schema 校验；高置信度不等于自动正确。

## 反例

- `confidence = 0.61` 仍返回 `status = "confirmed"`。
- 低置信度结果直接进入复习计划。
- 代码里使用未解释的 magic number，例如 `0.8`，但 Knowledge 中没有记录。

## 过期条件

- 当自动化测试覆盖低置信度分支，并接入 G3 或业务验证脚本后，此 rule 可退休。
- 如果产品通过数据重新校准阈值，必须先更新 `knowledge/PRODUCT.md`，再更新规则和测试。

