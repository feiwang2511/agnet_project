# 错题管理增强 - EVALUATE

## 任务信息

- Task ID: `question-management`
- Profile: `feature`
- 当前阶段: `EVALUATE`
- 日期: 2026-06-28

## 任务摘要

增强错题管理功能：支持多选批量删除、已确认错题的编辑，以及在错题管理和复习界面展示拍照原图。页面设计需要合理美观。

## 用户目标

家长需要高效管理错题：批量清理无用题目、修正已确认题目内容，并能随时回看原始题目图片辅助确认和复习。

## Scope

本任务覆盖：

- 原始图片存储（S3）和展示
- 错题列表多选批量删除
- 已确认错题的编辑功能
- 错题管理和复习界面展示原图
- 前端 UI 重新设计，使其更美观合理

本任务不覆盖：

- 识别算法调优
- 新增知识点分类体系
- 用户认证和权限

## Knowledge 引用

- `knowledge/PRODUCT.md` BR-001: 已确认错题必须关联至少一个知识点
- `knowledge/PRODUCT.md` BR-004: AI 识别结果不能直接覆盖用户确认内容
- `governance/rules/R003-no-secret-or-private-data-leak.md`: 图片存储不泄漏隐私
- `knowledge/TECH.md` ADR-001: DynamoDB 单表设计（图片不适合存 DynamoDB，用 S3）

## 验收标准

### AC-001: 识别时保存原始图片到 S3

- Given 用户上传图片并成功识别
- When 系统保存识别结果
- Then 原始图片被存储到 S3，question 记录包含 image_url
- And 图片 URL 可公开访问（S3 公开读）

### AC-002: 错题管理界面展示原图

- Given 错题列表中存在有 image_url 的题目
- When 用户查看错题管理
- Then 每道题显示缩略图，点击可放大查看

### AC-003: 复习界面展示原图

- Given 复习列表中存在有 image_url 的题目
- When 用户进入复习
- Then 题目卡片显示原图辅助复习

### AC-004: 多选批量删除

- Given 用户在错题管理界面
- When 用户勾选多道题并点击批量删除
- Then 被选中的题目全部从数据库删除
- And 界面实时更新

### AC-005: 已确认错题编辑

- Given 一道已确认的错题
- When 用户点击编辑并修改题目/答案/知识点
- Then 修改被保存
- And 知识点不能为空（BR-001）

### AC-006: 页面设计美观合理

- Given 前端页面
- Then 布局清晰、配色协调、交互流畅
- And 移动端友好

## 风险

| 风险 | 影响 | 处理 |
| --- | --- | --- |
| 图片存 S3 增加存储成本 | 低，K12 场景图片量有限 | 设置生命周期策略 |
| 批量删除误操作 | 数据丢失 | 二次确认弹窗 |
| DynamoDB item 400KB 限制 | 不能存 base64 图片 | 用 S3 存图，DynamoDB 只存 URL |

## 不可逆决策声明

- 新增 S3 bucket 存储用户图片，属于数据存储策略变更
- 需记录 ADR-005: 用户图片使用 S3 存储

## G1 自检

- [x] evaluate.md 存在
- [x] 任务摘要和用户目标一致
- [x] AC >= 3 条且可判定
- [x] Knowledge 引用完整
- [x] 不可逆决策已声明

## G1 结论

EVALUATE artifact 满足 G1 条件，进入 PLAN 阶段。
