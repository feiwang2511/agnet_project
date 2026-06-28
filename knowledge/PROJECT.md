# 错题本 - 项目状态

## 当前 Sprint

Sprint 4: AgentOS 完善 + 全业务流程

## 当前目标

AgentOS 体系搭建完成，错题本核心业务流程（识别 → 确认 → 复习）已部署上线。当前处于 Day 3 阶段：验证、蒸馏、Loop 配置。

## 已完成

- [x] LAB-MANUAL 整体思路整理
- [x] Knowledge 目录初始化（PRODUCT/TECH/IMPROVEMENT/PROJECT）
- [x] Governance 目录初始化（Principles/Rules/Gates）
- [x] Hooks 注册与 Knowledge 自动注入（SessionStart + SessionEnd）
- [x] Delivery Engine 阶段和 Gate 设计
- [x] 拍照识别功能 SDLC 实弹（G1-G4 全部通过，DONE）
- [x] 完整业务流程：家长确认/放弃 + 学生复习
- [x] AWS 部署：Lambda + API Gateway + DynamoDB + S3
- [x] Eval 系统：golden-set + run-eval.sh（100% 通过）
- [x] 业务验证：ci/verify.sh（11/11 通过）
- [x] Loop 配置：停止条件 + 熔断条件 + 成本治理 + 升级策略
- [x] 30/60/90 行动计划

## 当前决策

- 使用"错题本 / cuotiben"作为 AgentOS 练习项目载体。
- Knowledge 与 Governance 采用教学版落地：每条关键规则写清选择、理由和判定标准。
- Delivery Engine 使用四阶段：EVALUATE -> PLAN -> BUILD -> VERIFY。
- 默认任务 profile 为 feature；明确 bug、hotfix、refactor 可走简化路径。
- 只有 G4 通过后，才能把任务状态标记为 DONE。
- 拍照识别任务使用 `feature` profile，Task ID 为 `recognize`，已 DONE。
- 前端使用 Vanilla JS + S3 静态网站。
- 后端单 Lambda 处理所有端点。
- DynamoDB 单表设计，partition key 为 question_id。
- 掌握判定：连续答对 3 次（correct_streak >= 3）。

## 部署信息

- Lambda: `cuotiben-recognize` (us-east-1)
- API Gateway: `https://hrlx9t2lub.execute-api.us-east-1.amazonaws.com/prod`
- DynamoDB: `cuotiben-questions`
- S3 Frontend: `http://cuotiben-frontend-375297.s3-website-us-east-1.amazonaws.com`

## 阻塞

- 当前无阻塞。

## 下一步

- 在真实场景中使用 AgentOS 完成新功能任务
- 积累 corrections 并执行首次蒸馏
- 持续跑 eval 监控系统健康度
