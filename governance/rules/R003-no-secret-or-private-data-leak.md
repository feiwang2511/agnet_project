# Rule: 不得泄漏凭证和用户隐私数据

## 追溯

- Principle: P1（完成 = 主动验证且没有失败项）
- Principle: P2（宁可进入待确认，也不让脏数据进入正式学习链路）
- Knowledge: `knowledge/IMPROVEMENT.md` 的禁止事项

## 判定标准

代码、日志、文档和测试 fixture 中不得包含：

- 真实 API key、AWS access key、secret key、session token。
- 真实用户图片内容或可识别个人身份的信息。
- Bedrock 请求中的完整敏感 payload 日志。

允许出现：

- 明确标记为示例的占位符，例如 `example-api-key`。
- 经过脱敏的 request id、trace id。
- 最小化的合成测试数据。

## 反例

- 在 `.py`、`.md` 或 `.env.example` 中写入真实 key。
- 调试时把完整 base64 图片写进日志。
- 测试文件使用真实学生姓名和真实拍照内容。

## 过期条件

- 不能完全过期；安全隐私类 rule 至少保留在 Principle 或 Gate 中。
- 当自动 secrets scan gate 稳定运行 60 天后，本 rule 可压缩为更短说明，详细检查交给 Gate。

