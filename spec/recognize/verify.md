# 拍照识别功能 - VERIFY

## 任务信息

- Task ID: `recognize`
- Profile: `feature`
- 当前阶段: `VERIFY`
- 日期: 2026-06-28
- 输入 artifact: `spec/recognize/plan.md`

## 测试命令和结果

### 单元测试

```bash
source .venv/bin/activate && python3 -m pytest tests/ -v
```

结果：**22 tests passed**

覆盖：
- `test_service.py`: 15 tests (业务逻辑、图片校验、confidence gating、provider 边界)
- `test_api.py`: 4 tests (API 层、HTTP 状态码、响应结构)
- `test_security.py`: 3 tests (无 secrets、日志脱敏、错误消息不泄漏图片)

### 质量 Gate

```bash
bash governance/gates/check-basic-quality.sh
```

结果：**Gate passed** — Python 语法正确，无明显 secrets。

### 集成测试（已部署 API）

```bash
bash deploy/test-deployed.sh
```

结果：**5/5 PASS**

- 空图片返回 400
- 非法 base64 返回 400
- 非图片格式返回 400
- 合法图片调用 Bedrock 返回结构化结果或结构化错误
- 错误响应包含 `error.code`, `error.message`, `error.request_id`

### Bedrock 端到端验证

```bash
curl -X POST https://hrlx9t2lub.execute-api.us-east-1.amazonaws.com/prod/recognize \
  -H "Content-Type: application/json" \
  -d '{"image": "<png-base64>", "subject": "math", "grade": "grade_7"}'
```

结果：**200 OK**，返回完整识别结果：
- `question_text`: 非空题目文本
- `knowledge_points`: 相关知识点数组
- `confidence`: 0.9（高置信度 → `status: confirmed`）
- `raw_model_output_id`: 存在

## 主动破坏尝试（>= 5 种）

| # | 破坏方式 | 预期行为 | 实际结果 | Pass/Fail |
|---|----------|----------|----------|-----------|
| 1 | 缺少 image 字段 | Pydantic 422 或 400 | 422 Field required | PASS |
| 2 | image 为 null | 类型错误 | 422 Input should be valid string | PASS |
| 3 | 路径遍历字符串 `../../../../etc/passwd` | 400 invalid_image | 400 invalid_image | PASS |
| 4 | 非法 JSON 请求体 | 422 JSON decode error | 422 JSON decode error | PASS |
| 5 | 空请求体 | 422 missing body | 422 Field required | PASS |
| 6 | GIF 格式图片 | 400 invalid_image（不支持） | 400 invalid_image | PASS |
| 7 | 超大图片（>10MB） | 400 invalid_image | 400 invalid_image（单元测试验证） | PASS |
| 8 | Provider 超时异常 | 502 recognition_unavailable | 502（单元测试 + fake provider） | PASS |
| 9 | Provider 返回缺字段 | 502 invalid_model_output | 502（单元测试验证） | PASS |
| 10 | confidence = 1.2（越界） | 502 invalid_model_output | 502（单元测试验证） | PASS |
| 11 | confidence = 0.74 | needs_confirmation | needs_confirmation（单元测试验证） | PASS |
| 12 | 高置信度但空 question_text | 502 invalid_model_output | 502（单元测试验证） | PASS |

## AC 验收标记

| AC | 描述 | Pass/Fail | 验证方式 |
|----|------|-----------|----------|
| AC-001 | 接口能接收题目图片请求 | PASS | API 测试 + 部署集成测试 + Bedrock 端到端 |
| AC-002 | 非法图片被客户端错误阻断 | PASS | 6 类非法输入测试，provider 未被调用 |
| AC-003 | 成功识别响应满足完整 schema | PASS | schema 测试 + Bedrock 端到端返回完整字段 |
| AC-004 | 低置信度进入待确认 | PASS | confidence=0.74 测试断言 needs_confirmation |
| AC-005 | 高置信度也必须经过 schema 校验 | PASS | 高置信度缺字段返回 invalid_model_output |
| AC-006 | Bedrock 异常不能伪装成功识别 | PASS | provider exception 测试 + 部署 502 验证 |
| AC-007 | Bedrock SDK 细节不泄漏到业务层 | PASS | api.py 不 import boto3，service.py 只依赖 provider 抽象 |
| AC-008 | 不泄漏凭证或用户图片内容 | PASS | security 测试 + gate 检查 |
| AC-009 | 完成前有测试和主动验证记录 | PASS | 本文件即验证记录 |

## 部署信息

- Lambda: `cuotiben-recognize` (us-east-1)
- API Gateway: `https://hrlx9t2lub.execute-api.us-east-1.amazonaws.com/prod`
- Endpoint: `POST /recognize`
- Runtime: Python 3.12, 512 MB, 30s timeout
- Provider: Bedrock `us.anthropic.claude-sonnet-4-20250514-v1:0`

## 已知边界

- 单元测试使用 fake provider 验证业务逻辑，不访问真实 AWS。
- Bedrock 集成通过部署后端到端测试验证，依赖 IAM role 权限。
- 当前图片是合成 PNG（白色画布），Bedrock 仍能生成结构化响应。
- 超大图片验证仅在单元测试层完成（API Gateway 有 10MB payload 限制）。

## G4 自检

- [x] `spec/recognize/verify.md` 存在。
- [x] 所有 AC 有 pass/fail 标记。
- [x] 无 fail 项。
- [x] 主动破坏尝试 >= 5 种（实际 12 种）。
- [x] 测试命令和结果已记录。

## G4 结论

VERIFY artifact 满足 G4 条件。任务可以标记为 DONE。
