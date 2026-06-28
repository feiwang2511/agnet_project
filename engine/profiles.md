# Delivery Engine - Profiles

Profile 定义不同任务类型应该走哪些阶段。它避免所有任务都用同一套重流程，也避免高风险任务被过度简化。

## Profile: feature（默认）

**路径**：

```text
EVALUATE -> PLAN -> BUILD -> VERIFY
```

**适用**：

- 新功能开发。
- 影响 API、数据模型、用户流程的变更。
- 需求还需要拆解或存在明显设计空间的任务。

**Gate 调整**：

- G1 要求 AC 数量 >= 3。
- G2 默认 L2。
- 涉及不可逆决策时升级 L3。

**示例**：

- 为错题本开发“拍照识别”功能。
- 新增知识点复习计划生成。

## Profile: bugfix

**路径**：

```text
EVALUATE -> BUILD -> VERIFY
```

**适用**：

- 已知 bug，方向明确。
- 不改变架构，不改变接口契约。
- 修复目标能用一个或少量回归测试表达。

**Gate 调整**：

- G1 的 AC 要求降为 >= 1。
- 可以跳过 PLAN，但如果发现根因不清或影响范围扩大，必须升级到 feature 或 refactor。

**示例**：

- `confidence = 0.61` 时错误返回 `confirmed`。
- 缺失 `knowledge_points` 字段时没有触发 schema 错误。

## Profile: hotfix

**路径**：

```text
BUILD -> VERIFY
```

**适用**：

- 线上紧急问题。
- 已经明确修复点。
- 延迟修复会造成用户损失或数据污染。

**Gate 调整**：

- G3 只要求最小相关测试和基础质量 Gate 通过。
- G4 必须记录修复证据。
- 事后必须补 EVALUATE/PLAN 复盘 artifact。

**示例**：

- 识别接口正在泄漏完整图片 payload 日志，需要立即关闭。

## Profile: refactor

**路径**：

```text
PLAN -> BUILD -> VERIFY
```

**适用**：

- 不改变外部行为，只改善结构。
- 目标是降低复杂度、隔离依赖或提升可测试性。

**Gate 调整**：

- PLAN 必须说明行为不变边界。
- G4 必须包含回归测试证据。
- 如果出现行为改变，回退 EVALUATE，重新定性为 feature。

**示例**：

- 把 Bedrock SDK 调用封装到 provider 层。
- 把 schema 校验从 handler 中抽出。

## Profile 选择规则

1. 默认选 `feature`。
2. 如果任务是明确 bug 且根因清晰，选 `bugfix`。
3. 如果是线上紧急风险，选 `hotfix`，但必须事后补 artifact。
4. 如果目标是不改行为的结构调整，选 `refactor`。
5. 不确定时选更保守的 profile。

