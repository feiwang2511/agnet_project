# 错题本 - 项目状态

## 当前 Sprint

Sprint 3: 核心识别功能

## 当前目标

建立拍照识别能力的 AgentOS 工作基础：Knowledge、Governance、Hooks 和 Delivery Engine 已完成，下一步用“拍照识别”任务跑一遍 SDLC。

## 进行中

- [x] LAB-MANUAL 整体思路整理
- [x] Knowledge 目录初始化
- [x] Governance 目录初始化
- [x] Hooks 注册与 Knowledge 自动注入
- [x] Delivery Engine 阶段和 Gate 设计
- [ ] 拍照识别功能 SDLC 实弹（当前：PLAN 完成，G1/G2 通过，进入 BUILD）

## 当前决策

- 使用“错题本 / cuotiben”作为 AgentOS 练习项目载体。
- Knowledge 与 Governance 采用教学版落地：每条关键规则写清选择、理由和判定标准。
- Delivery Engine 使用四阶段：EVALUATE -> PLAN -> BUILD -> VERIFY。
- 默认任务 profile 为 feature；明确 bug、hotfix、refactor 可走简化路径。
- 只有 G4 通过后，才能把任务状态标记为 DONE。
- 拍照识别任务使用 `feature` profile，Task ID 为 `recognize`。
- `spec/recognize/evaluate.md` 已作为 EVALUATE artifact，G1 已通过。
- `spec/recognize/plan.md` 已作为 PLAN artifact，G2 已通过。
- `knowledge/TECH.md` 已新增 ADR-004，用于记录结构化错误响应契约。

## 阻塞

- 当前无阻塞。

## 下一个检查点

进入 SDLC 实弹前，应能回答：

1. 新任务应该选择哪个 profile？
2. EVALUATE 阶段如何写可判定 AC？
3. PLAN 阶段如何把 AC 映射到实现和验证？
4. BUILD 阶段发现方向问题时，为什么要回退 PLAN？
5. VERIFY 阶段如何证明“主动破坏且失败”？

当前下一步：

1. 按 `spec/recognize/plan.md` 执行 BUILD。
2. 先写失败测试，再实现最小代码。
3. 创建识别服务代码、provider 边界和 FastAPI adapter。
4. 运行 G3: BUILD -> VERIFY。
