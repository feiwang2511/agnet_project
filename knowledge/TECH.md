# 错题本 - 技术知识

## 技术栈

- 前端：React 19 + Tailwind CSS
- 后端：Python FastAPI
- 数据库：DynamoDB
- AI：AWS Bedrock Claude，用于图片识别和结构化抽取
- 部署：AWS Lambda + API Gateway
- 测试：pytest + 接口级 schema 校验

## 不可逆决策定义

一个决策满足以下任一条件时，必须记录为 ADR：

1. 改变数据模型后迁移成本高。
2. 更换供应商或基础设施会影响大量代码。
3. 接口契约发布后会影响前端、后端或外部调用方。
4. 错误决策会污染用户数据或学习计划。

## 不可逆决策（Architecture Decision Records）

### [ADR-001] 使用 DynamoDB 而非 RDS

- 状态：已接受
- 理由：错题本以用户、题目、知识点维度的读多写少访问为主，DynamoDB 单表设计适合高并发、低运维的 Serverless 架构。
- 代价：复杂 ad-hoc 查询能力弱，后续需要提前设计访问模式。
- 不可逆原因：DynamoDB 和 RDS 的数据建模方式差异大，后续迁移会影响数据结构、查询代码和索引策略。
- 判定标准：新增查询需求时，必须先写出访问模式，再决定是否增加 GSI。

### [ADR-002] 使用 Bedrock Claude 而非自建模型

- 状态：已接受
- 理由：当前团队不投入 ML 训练和推理基础设施，用托管模型更快验证产品价值。
- 代价：成本随调用量增长；识别质量受模型能力、提示词和后处理影响。
- 不可逆原因：Prompt、返回解析、错误处理和评估流程会与 Bedrock Claude 的能力深度耦合。
- 判定标准：识别逻辑必须封装在 provider 边界内，业务层不能直接依赖 Bedrock SDK 细节。

### [ADR-003] 识别结果采用 schema-first 契约

- 状态：已接受
- 理由：识别结果会驱动前端展示、知识点归类和复习计划，字段缺失会造成链路污染。
- 代价：开发早期需要维护 schema 和校验代码。
- 不可逆原因：接口一旦被前端和数据存储使用，字段含义变化会带来兼容成本。
- 判定标准：识别接口返回前必须经过 schema 校验；缺失核心字段时不能返回成功状态。

### [ADR-004] 识别接口错误采用结构化错误响应

- 状态：已接受
- 理由：前端和调用方需要稳定判断错误类型，不能依赖自然语言错误文本。
- 代价：需要维护错误码、HTTP 状态和用户可见消息之间的映射。
- 不可逆原因：错误响应一旦被前端消费，随意改变字段或错误码会造成兼容问题。
- 判定标准：识别接口失败时返回 `error.code`、`error.message`、`error.request_id`，且不得包含凭证或完整图片内容。

## 接口契约

### POST /recognize

用途：接收一张题目图片，调用 AI 识别并返回结构化结果。

请求：

```json
{
  "image": "base64-encoded-image",
  "subject": "math",
  "grade": "grade_7"
}
```

响应：

```json
{
  "question_text": "string",
  "answer": "string | null",
  "knowledge_points": ["string"],
  "confidence": 0.82,
  "status": "confirmed | needs_confirmation",
  "raw_model_output_id": "string"
}
```

契约要求：

- `confidence` 永远存在，取值范围为 `[0, 1]`。
- `question_text` 必须是非空字符串。
- `knowledge_points` 必须是数组；无法识别时返回空数组，并将状态设为 `needs_confirmation`。
- Bedrock 调用失败时不能返回伪造的成功识别结果。
- 任何新增字段必须同步更新接口契约、测试和前端消费方。

错误响应：

```json
{
  "error": {
    "code": "invalid_image",
    "message": "Image must be a non-empty JPEG or PNG under 10 MB.",
    "request_id": "req_..."
  }
}
```

错误码：

- `invalid_image`: 图片为空、base64 无法解码、格式不支持或超过大小限制。
- `recognition_unavailable`: Bedrock 超时、限流、权限失败或不可用。
- `invalid_model_output`: Bedrock 返回缺字段、类型错误、confidence 越界或不可解析内容。

### [ADR-005] 用户图片使用 S3 存储

- 状态：已接受
- 理由：DynamoDB 单 item 400KB 限制不适合存储图片；复用已有 S3 静态网站 bucket 无需额外配置公开访问。
- 代价：图片公开可访问（无认证），适合当前无用户认证阶段；后续加认证需迁移到 CloudFront + signed URL。
- 不可逆原因：图片 URL 格式被前端和 DynamoDB 记录引用后，变更路径会影响历史数据展示。
- 判定标准：图片存储在 `s3://cuotiben-frontend-375297/images/{question_id}.{ext}`；DynamoDB 记录 `image_url` 字段。

## 错误处理约束

- 图片为空、过大或格式不支持时，返回可判定的客户端错误。
- Bedrock 超时或异常时，返回服务端错误，并记录可追踪的 request id。
- 低置信度不是系统错误，而是业务状态 `needs_confirmation`。
- 不能把 API key、模型凭证或用户图片内容写入日志。
