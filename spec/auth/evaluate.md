# 登录注册功能 - EVALUATE

## 任务信息

- Task ID: `auth`
- Profile: `feature`
- 当前阶段: `EVALUATE`
- 日期: 2026-06-28

## 任务摘要

为错题本添加登录注册功能。用户必须注册并登录后才能进入系统。注册时选择角色（家长/学生）。当前不做数据隔离，仅实现认证门控。

## 用户目标

让系统有基本的用户身份概念，为后续多用户数据隔离打基础。当前只需要：能注册、能登录、未登录时不能使用系统。

## Scope

本任务覆盖：

- 用户注册（用户名 + 密码 + 角色选择）
- 用户登录
- 登录态维护（前端 token 存储）
- 未登录时拦截，跳转登录页
- 后端注册/登录 API

本任务不覆盖：

- 数据隔离（不按用户过滤题目）
- OAuth / 第三方登录
- 密码找回
- 邮箱验证
- Session 过期自动刷新

## Knowledge 引用

- `knowledge/TECH.md` ADR-001: DynamoDB 单表设计
- `governance/rules/R003-no-secret-or-private-data-leak.md`: 密码不能明文存储

## 验收标准

### AC-001: 用户可以注册

- Given 未注册用户
- When 填写用户名、密码、角色（家长/学生）并提交
- Then 注册成功，跳转登录页
- And 用户名重复时提示已存在

### AC-002: 用户可以登录

- Given 已注册用户
- When 填写正确用户名密码
- Then 登录成功，进入主界面
- And 密码错误时提示错误

### AC-003: 未登录拦截

- Given 未登录用户
- When 试图访问主界面
- Then 被重定向到登录页

### AC-004: 密码安全存储

- Given 用户注册
- Then 密码使用哈希存储，不明文保存

### AC-005: 登录态维持

- Given 用户已登录
- When 刷新页面
- Then 保持登录状态（token 存 localStorage）

## 风险

| 风险 | 处理 |
| --- | --- |
| 密码明文存储 | 使用 hashlib sha256 + salt |
| Token 伪造 | 简单 JWT 签名验证 |
| 暴力破解 | 当前不处理，后续可加限流 |

## 不可逆决策

- DynamoDB 新增 `cuotiben-users` 表，partition key: username
- 认证方案选择简单 JWT（不依赖 Cognito）

## G1 自检

- [x] evaluate.md 存在
- [x] AC >= 3 可判定
- [x] Knowledge 引用
- [x] 不可逆决策声明

## G1 结论

满足 G1，进入 PLAN。
