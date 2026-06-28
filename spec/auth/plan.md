# 登录注册功能 - PLAN

## 任务信息

- Task ID: `auth`
- Profile: `feature`
- 当前阶段: `PLAN`
- 日期: 2026-06-28

## 实现方案

### 后端

1. 新建 `app/auth/` 模块
   - `db.py`: DynamoDB users 表 CRUD（register, authenticate）
   - `api.py`: POST /auth/register, POST /auth/login
   - `jwt_util.py`: JWT 生成和验证（使用 hmac + base64，不引入第三方库）

2. DynamoDB 新表 `cuotiben-users`
   - Partition key: `username` (String)
   - Fields: username, password_hash, salt, role, created_at

3. 密码存储：sha256(salt + password)，salt 随机生成

4. JWT: HS256 签名，payload 含 username + role + exp，secret 用环境变量

### 前端

1. 新增登录/注册页面（在主内容之前）
2. localStorage 存 token
3. 每次加载检查 token 有效性
4. 未登录显示登录页，已登录显示主界面
5. 顶部显示用户名和角色，支持登出

### 不做的事

- 不做 API 层 token 验证中间件（当前不做数据隔离）
- 不做密码强度校验
- 不做 token 自动刷新

## G2 结论

方案简单明确，进入 BUILD。
