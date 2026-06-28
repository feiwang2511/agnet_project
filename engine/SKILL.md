---
trigger: "开始任务" OR "run engine" OR "用 engine 跑" OR "执行任务"
---

# Delivery Engine Skill

当用户下发需要交付的任务时，使用本流程。目标是让 Agent 不直接跳到实现，而是按 EVALUATE、PLAN、BUILD、VERIFY 的阶段推进。

## 启动前必须读取

1. `knowledge/PROJECT.md`
2. `governance/principles.md`
3. `engine/STATE.md`
4. `engine/stages.md`
5. `engine/gates.md`
6. `engine/profiles.md`

如果任务涉及识别、schema、置信度、知识点、Bedrock 或复习计划，还必须读取：

1. `knowledge/PRODUCT.md`
2. `knowledge/TECH.md`
3. `knowledge/IMPROVEMENT.md`
4. `governance/rules/*.md`

## 执行流程

### 1. 判断是新任务还是续做

读取 `engine/STATE.md`：

- 如果当前阶段是 `IDLE`、`DONE` 或任务为空，则视为新任务。
- 如果当前阶段是 `EVALUATE`、`PLAN`、`BUILD`、`VERIFY` 或 `BLOCKED`，则先向用户说明当前状态，再继续或请求确认。

### 2. 选择 Profile

根据 `engine/profiles.md` 判断任务类型：

- 新功能或重大变更：`feature`
- 明确 bug 修复：`bugfix`
- 紧急线上修复：`hotfix`
- 不改行为的结构调整：`refactor`

不确定时选择 `feature`。

### 3. 初始化 STATE

更新 `engine/STATE.md`：

- 任务名称
- Profile
- 当前阶段
- 已通过 Gates
- 开始时间
- 当前阻塞

### 4. 执行当前阶段

根据 `engine/stages.md` 执行对应阶段：

- `EVALUATE`：产出 `spec/<task-id>/evaluate.md`
- `PLAN`：产出 `spec/<task-id>/plan.md`
- `BUILD`：产出代码、测试和必要文档
- `VERIFY`：产出 `spec/<task-id>/verify.md`

### 5. 运行出口 Gate

每个阶段结束时，读取 `engine/gates.md` 中对应 Gate：

- EVALUATE 结束后运行 G1
- PLAN 结束后运行 G2
- BUILD 结束后运行 G3
- VERIFY 结束后运行 G4

Gate 通过：

- 更新 `engine/STATE.md`
- 进入下一阶段

Gate 失败：

- 按 Gate 的失败处理执行
- 原地修复、回退上一阶段或升级给用户

### 6. 完成条件

只有 G4 通过时，才可以将 `engine/STATE.md` 更新为 `DONE`，并声称任务完成。

## 强制规则

- 不允许跳过当前 profile 要求的阶段。
- 不允许在 BUILD 阶段做未记录的方向性决策。
- 不允许在没有 verify artifact 时声称完成。
- 不允许在有 fail 项时声称完成。
- 不允许绕过 active rules。
- 涉及不可逆决策时，必须更新 ADR 或升级给用户。

## 推荐任务 ID 规则

任务 ID 使用短横线命名：

```text
recognize-photo
fix-confidence-gating
refactor-bedrock-provider
```

对应 artifact 放在：

```text
spec/<task-id>/evaluate.md
spec/<task-id>/plan.md
spec/<task-id>/verify.md
```

