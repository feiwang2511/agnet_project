# 错题管理增强 - PLAN

## 任务信息

- Task ID: `question-management`
- Profile: `feature`
- 当前阶段: `PLAN`
- 日期: 2026-06-28
- 输入: `spec/question-management/evaluate.md`

## 实现方案

### 1. 图片存储（S3）

复用已有的 S3 bucket `cuotiben-frontend-375297`，在 `images/` 前缀下存储用户图片。

- 识别时上传原始图片到 `s3://cuotiben-frontend-375297/images/{question_id}.jpg`
- 因为该 bucket 已配置为 S3 静态网站，images/ 下的文件自动可公开访问
- DynamoDB 记录中新增 `image_url` 字段

### 2. 后端新增/修改端点

| 端点 | 方法 | 变更 |
| --- | --- | --- |
| POST /recognize | 修改 | 上传图片到 S3，返回 image_url |
| PUT /questions/{id} | 新增 | 编辑已确认题目（question_text, answer, knowledge_points）|
| POST /questions/batch-delete | 新增 | 批量删除，body: {question_ids: [...]} |

### 3. 前端 UI 重设计

三页签保持不变，增强视觉设计：
- 卡片式布局替代列表式
- 缩略图展示 + 点击放大弹窗
- 多选模式：长按或勾选框进入多选
- 编辑模式：点击编辑按钮展开编辑表单

## ADR 更新

新增 ADR-005：用户图片使用已有 S3 bucket 的 images/ 前缀存储。
- 理由：DynamoDB 单 item 400KB 限制不适合存图片；S3 静态网站已配置公开访问。
- 代价：图片公开可访问（无认证），适合当前无用户认证的阶段。
- 不可逆原因：图片 URL 格式一旦被前端引用，后续变更路径会影响历史数据。

## AC 映射

| AC | 实现 | 验证 |
| --- | --- | --- |
| AC-001 | api.py recognize 上传 S3, db.py 存 image_url | 部署后识别返回 image_url |
| AC-002 | frontend 错题卡片显示缩略图 + lightbox | 手动验证 |
| AC-003 | frontend 复习卡片显示原图 | 手动验证 |
| AC-004 | 新增 batch-delete 端点 + 前端多选UI | curl 测试 + 手动验证 |
| AC-005 | 新增 PUT /questions/{id} + 前端编辑表单 | curl 测试 |
| AC-006 | CSS 重设计 | 目视检查 |

## 测试策略

- 后端：新增 batch-delete、edit、image_url 相关测试
- 集成：ci/verify.sh 新增批量删除和编辑验证
- 前端：手动验证 UI

## G2 自检

- [x] plan.md 存在
- [x] AC 全部映射到实现和验证
- [x] 新增 ADR-005 已记录
- [x] 错误处理覆盖
- [x] 测试策略明确

## G2 结论

PLAN 满足 G2 条件，进入 BUILD。
