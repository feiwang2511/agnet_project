# AgentOS 工程实践（进阶）— 实验操作手册

> **版本**: v2.0
> **配套**: script_v2 课程脚本
> **环境**: AWS Workshop（VSCode Server + Claude Code CLI + Bedrock）
> **项目载体**: 错题本（cuotiben）

---

## 环境准备

### 前置确认

```bash
# 确认 Claude Code 可用
claude --version

# 确认工作目录
pwd
# 应在你的 workshop 环境目录下
```

### 初始化 AgentOS Repo

```bash
mkdir my-agentos && cd my-agentos && git init
```

> 从现在开始，三天里所有产出都进这个目录。三天后它就是你的 AgentOS。

---

## Day 1 — AgentOS 全景 + Knowledge 模块

---

### Lab 1：初始化 Knowledge 骨架（Module 03）

**时间**: 20 min
**目标**: 为错题本初始化 DDD 四文档 + Capture Hook

#### Step 1：创建目录结构

```bash
mkdir -p knowledge governance/rules governance/rules/_retired governance/gates governance/gates/_graduated hooks spec eval ci docs
touch corrections.log
```

#### Step 2：编写 PRODUCT.md

创建 `knowledge/PRODUCT.md`：

```markdown
# 错题本 — 产品知识

## 用户
K12 学生家长（代孩子管理错题）

## 核心问题
纸质错题本：收集麻烦、检索困难、复习无序

## 核心概念
- 错题（Question）：一道被拍照录入的题目
- 识别（Recognition）：AI 将图片转为结构化数据
- 知识点（KnowledgePoint）：题目考查的能力维度
- 复习计划（ReviewPlan）：基于遗忘曲线的推荐

## 业务规则
- 一道错题必须关联至少一个知识点
- 识别结果 confidence < ___（你选的阈值）必须标记"待确认"
  - 理由：___
  - 判定标准：___
- 同一知识点连续 ___ 次正确 → 标记"已掌握"
  - 理由：___
```

**判断点**：
- confidence 阈值你选多少？为什么不是 0.5？为什么不是 0.9？
- "连续 N 次正确"的 N 你选多少？依据是什么？
- 每个数值都需要：**选择 + 理由 + 判定标准**

#### Step 3：编写 TECH.md

创建 `knowledge/TECH.md`：

```markdown
# 错题本 — 技术知识

## 技术栈
- 前端：React 19 + Tailwind
- 后端：Python FastAPI
- 数据库：DynamoDB
- AI：AWS Bedrock (Claude) — 图片识别
- 部署：AWS Lambda + API Gateway

## 不可逆决策（Architecture Decision Records）

### [ADR-001] DynamoDB 而非 RDS
- **理由**: 单表设计适合题目的读多写少模式
- **代价**: 复杂查询能力受限
- **不可逆原因**: 数据模型完全不同，迁移 = 重写

### [ADR-002] Bedrock 而非自建模型
- **理由**: 不投入 ML 团队，用服务买时间
- **代价**: 成本随调用量线性增长
- **不可逆原因**: prompt 设计和后处理与 Claude API 耦合

## 接口契约
- 识别接口返回 JSON schema
- confidence 字段永远存在，取值 [0, 1]
```

**判断点**：
- 你的 ADR 什么条件被标为"不可逆"？标准是什么？
- 还有没有其他不可逆决策没有记录？

#### Step 4：编写 IMPROVEMENT.md 和 PROJECT.md（骨架）

`knowledge/IMPROVEMENT.md`：

```markdown
# 错题本 — 改进方向

## 优先级
1. 识别准确率（当前 baseline 未建立）
2. 首次使用体验（拍照→识别 < 5秒）

## 已知 Tech Debt
- 错误处理不统一
- 测试覆盖率未知

## 禁止事项
- 不要动 auth 模块（正在重构）
- 不要添加 ORM（与 DynamoDB 单表设计冲突）
```

`knowledge/PROJECT.md`：

```markdown
# 错题本 — 项目状态

## 当前 Sprint
Sprint 3: 核心识别功能

## 进行中
- [ ] 拍照上传 API
- [ ] Bedrock 识别调用
- [x] DynamoDB schema 设计

## 阻塞
- （当前无）
```

#### Step 5：编写 Capture Hook

创建 `hooks/on-session-end.sh`：

```bash
#!/bin/bash
# 触发时机：Claude Code session 结束时
# 做什么：提取 corrections，追加到 log

AGENTOS_DIR="$(dirname "$(dirname "$0")")"

claude --print "Review this session transcript.
Extract:
1. Any corrections the user made (format: CORRECTION: ...)
2. Any decisions made with rationale (format: DECISION: ...)
3. Any new facts discovered (format: DISCOVERY: ...)
Output ONLY the extracted items, one per line.
If none found, output NONE." \
>> "$AGENTOS_DIR/corrections.log"
```

```bash
chmod +x hooks/on-session-end.sh
```

#### 验证标准
- [ ] `knowledge/` 下有 4 个 .md 文件
- [ ] PRODUCT.md 中的阈值有选择 + 理由
- [ ] TECH.md 中至少有 2 条 ADR
- [ ] `hooks/on-session-end.sh` 存在且可执行
- [ ] `corrections.log` 存在（空文件）

---

### Lab 2：设计三层治理（Module 04）

**时间**: 30 min
**目标**: 为错题本设计 Principles + Rules + Gates

#### Step 1：编写 Principles

创建 `governance/principles.md`：

```markdown
# Principles（按优先级排序）

## P1: ___（你的最高优先级原则）
___（描述 + 判定标准）

## P2: ___
___

## P3: ___
___
```

**要求**：
- 3-5 条原则
- 每条必须**可判定**（能回答"做到了没有"）
- 有优先级排序
- 自检：如果删掉这条 principle，agent 会犯什么错？

**参考 starter（可直接使用或修改）**：
- P1 完成度："完成 = 我主动尝试破坏它且失败了，不是'我没发现明显问题'"
- P2 数据质量："宁可拒绝也不放脏数据进入系统"
- P3 命名："每个名字都应该让陌生人秒懂意图"

#### Step 2：编写 Rules

创建 `governance/rules/R001-schema-completeness.md`（示例）：

```markdown
# Rule: 识别接口必须返回完整 schema

## 追溯
- Principle: P2（数据质量是底线）
- Evidence: （待积累 corrections 后填写）

## 判定标准
- 识别接口返回 JSON 包含 `confidence: number`
- 取值范围 [0, 1]
- 包含 `question_text: string`（非空）

## 过期条件
- 当 Gate `check-schema.sh` 部署后，此 rule 可退休
- 或连续 30 天无此类违规时重新评估
```

至少写 2-3 条 Rules。每条必须有：追溯 + 判定标准 + 过期条件。

#### Step 3：编写一个 Gate 脚本

创建 `governance/gates/check-lint.sh`（示例）：

```bash
#!/bin/bash
# Gate: 代码必须通过 lint 检查
# 追溯: Principle P1 "完成 = 主动破坏且失败"
# 毕业条件: 连续 60 天不触发

# 检查 Python 文件的基本格式
if find . -name "*.py" -exec python -m py_compile {} \; 2>&1 | grep -q "Error"; then
  echo "❌ GATE BLOCKED: Python 语法错误"
  exit 1
fi

echo "✅ Gate passed: lint check"
```

```bash
chmod +x governance/gates/check-lint.sh
```

#### 蒸馏练习（可选）

使用以下模拟 corrections 做蒸馏：
```
CORRECTION: 跳过了 edge case 测试就说 done
CORRECTION: 函数命名用了 handle_stuff（不具体）
CORRECTION: 没有跑 lint 就提交了
CORRECTION: 改了 schema 没更新文档
CORRECTION: 把 API key 写在了代码里
CORRECTION: 说"应该没问题"而不是验证
CORRECTION: 命名用了缩写别人看不懂
CORRECTION: 改了 3 个文件但只测了 1 个
CORRECTION: 新增字段没有 migration
CORRECTION: 完成后没有自己试一遍
```

**练习**：分组 → 识别 pattern → 产出 principles/rules/gates

#### 验证标准
- [ ] `governance/principles.md` 有 3-5 条可判定原则
- [ ] 每条 principle 能回答"做到了没有"
- [ ] `governance/rules/` 下有 2-3 个 rule 文件
- [ ] 每条 rule 有追溯 + 判定标准 + 过期条件
- [ ] `governance/gates/` 下有 1 个可执行脚本

---

### Lab 3：实现 Retrieve + Health（Module 05）

**时间**: 30 min
**目标**: 实现 Knowledge 自动注入和健康检查

#### Step 1：编写 SessionStart Hook

创建 `hooks/on-session-start.sh`：

```bash
#!/bin/bash
# 触发时机：Claude Code session 启动时
# 做什么：注入 Knowledge 到 context

AGENTOS_DIR="$(dirname "$(dirname "$0")")"

# P0: Principles（最先注入 = 最高 attention）
echo "=== PRINCIPLES (最高优先级约束) ==="
cat "$AGENTOS_DIR/governance/principles.md"
echo ""

# P1: 当前状态
if [ -f "$AGENTOS_DIR/engine/STATE.md" ]; then
  echo "=== CURRENT STATE ==="
  cat "$AGENTOS_DIR/engine/STATE.md"
  echo ""
fi

# P2: DDD 摘要（每份取前 15 行作为摘要）
echo "=== DOMAIN KNOWLEDGE (摘要) ==="
for doc in PRODUCT TECH IMPROVEMENT PROJECT; do
  if [ -f "$AGENTOS_DIR/knowledge/$doc.md" ]; then
    echo "--- $doc ---"
    head -15 "$AGENTOS_DIR/knowledge/$doc.md"
    echo "..."
    echo ""
  fi
done

# P4: 禁止事项
if grep -q "## 禁止事项" "$AGENTOS_DIR/knowledge/IMPROVEMENT.md" 2>/dev/null; then
  echo "=== 禁止事项 ==="
  sed -n '/## 禁止事项/,/## /p' "$AGENTOS_DIR/knowledge/IMPROVEMENT.md" | head -10
fi

# Health summary
echo ""
echo "=== Health Status ==="
bash "$AGENTOS_DIR/knowledge/health.sh" 2>/dev/null | tail -3
```

```bash
chmod +x hooks/on-session-start.sh
```

#### Step 2：编写 Health Check 脚本

创建 `knowledge/health.sh`：

```bash
#!/bin/bash
# Knowledge 系统健康检查

AGENTOS_DIR="$(dirname "$(dirname "$0")")"
WARNINGS=0
ERRORS=0

echo "=== Knowledge Health Check ==="
echo ""

# 1. 新鲜度检查
echo "Freshness Check:"
for doc in PRODUCT TECH IMPROVEMENT PROJECT; do
  FILE="$AGENTOS_DIR/knowledge/$doc.md"
  if [ -f "$FILE" ]; then
    DAYS_OLD=$(( ($(date +%s) - $(stat -f %m "$FILE" 2>/dev/null || stat -c %Y "$FILE" 2>/dev/null)) / 86400 ))
    if [ "$doc" = "PROJECT" ] && [ "$DAYS_OLD" -gt 3 ]; then
      echo "  WARNING $doc.md: ${DAYS_OLD} days old (threshold: 3)"
      WARNINGS=$((WARNINGS + 1))
    elif [ "$DAYS_OLD" -gt 14 ]; then
      echo "  WARNING $doc.md: ${DAYS_OLD} days old (threshold: 14)"
      WARNINGS=$((WARNINGS + 1))
    else
      echo "  OK $doc.md: ${DAYS_OLD} days old"
    fi
  else
    echo "  ERROR $doc.md: MISSING"
    ERRORS=$((ERRORS + 1))
  fi
done
echo ""

# 2. 体积检查
echo "Size Check:"
TOTAL_WORDS=0
for f in $(find "$AGENTOS_DIR/knowledge" "$AGENTOS_DIR/governance" -name "*.md" 2>/dev/null); do
  WORDS=$(wc -w < "$f")
  TOTAL_WORDS=$((TOTAL_WORDS + WORDS))
done
ESTIMATED_TOKENS=$((TOTAL_WORDS * 4 / 3))
echo "  Total words: $TOTAL_WORDS"
echo "  Estimated tokens: ~$ESTIMATED_TOKENS"
if [ "$ESTIMATED_TOKENS" -gt 15000 ]; then
  echo "  WARNING Exceeds injection budget (15K). Consider distilling."
  WARNINGS=$((WARNINGS + 1))
else
  echo "  OK Within budget"
fi
echo ""

# 3. Rules 数量检查
echo "Rules Check:"
ACTIVE_COUNT=$(find "$AGENTOS_DIR/governance/rules" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
RETIRED_COUNT=$(find "$AGENTOS_DIR/governance/rules/_retired" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
echo "  Active rules: $ACTIVE_COUNT"
echo "  Retired rules: $RETIRED_COUNT"
if [ "$ACTIVE_COUNT" -gt 15 ]; then
  echo "  WARNING Too many active rules (>15). Distill needed."
  WARNINGS=$((WARNINGS + 1))
fi
echo ""

# Summary
echo "=== Summary ==="
echo "  Warnings: $WARNINGS | Errors: $ERRORS"
if [ "$ERRORS" -gt 0 ]; then
  echo "  UNHEALTHY - fix errors before proceeding"
  exit 1
elif [ "$WARNINGS" -gt 2 ]; then
  echo "  DEGRADED - schedule maintenance"
else
  echo "  HEALTHY"
fi
```

```bash
chmod +x knowledge/health.sh
```

#### Step 3：注册 Hooks

创建 `.claude/settings.json`（如果不存在）：

```bash
mkdir -p .claude
```

编辑 `.claude/settings.json`：

```json
{
  "hooks": {
    "SessionStart": [{
      "type": "command",
      "command": "./hooks/on-session-start.sh"
    }],
    "SessionEnd": [{
      "type": "command",
      "command": "./hooks/on-session-end.sh"
    }]
  }
}
```

#### Step 4：验证注入生效

```bash
# 开一个新 Claude Code session
claude

# 首条消息问：
# "请告诉我你知道的关于这个项目的 principles 是什么？"
```

**预期结果**：Agent 能复述你的 principles。

#### 验证标准
- [ ] `hooks/on-session-start.sh` 可执行
- [ ] `knowledge/health.sh` 可执行且输出正确状态
- [ ] Hooks 注册到 `.claude/settings.json`
- [ ] 新 session 中 agent 能说出你的 principles

---

### Lab 4：Knowledge 端到端整合验证（Module 06）

**时间**: 60 min（含观察和讨论）
**目标**: 跑一个完整 session，验证 Knowledge 模块的注入→工作→捕获闭环

#### 实验流程

**Step 1：验证注入**
1. 开新 session
2. 问："在开始工作之前，请告诉我你知道的关于这个项目的 principles 是什么？"
3. 验证 agent 能复述 principles + 了解项目基本信息

**Step 2：下发任务**
```
为错题本写一个 recognize 函数：接收一张图片，调用 Bedrock Claude 识别题目内容，返回结构化 JSON。
```

**Step 3：观察 + 纠正**
- 观察 agent 是否受 principles 约束
- **不要提前干预**——等 agent 犯错再纠正
- 常见可纠正的错误：
  - 不处理 Bedrock API 异常
  - 返回 JSON 没有 confidence 字段
  - 不写测试
  - 用 magic number

**Step 4：结束 session + 检查 capture**
```bash
# 退出 session 后，等几秒让 hook 执行
cat corrections.log
```

#### 验证标准
- [ ] Agent 启动时知道 principles（注入成功）
- [ ] Agent 的行为受到 principles 影响（至少部分）
- [ ] 你至少纠正了 2 次（corrections 产生）
- [ ] `corrections.log` 有内容（capture 成功）
- [ ] 内容格式正确（CORRECTION: / DECISION: / DISCOVERY:）

---

## Day 2 — Delivery Engine 设计 + SDLC 实弹

---

### Lab 5：设计 Engine 阶段序列（Module 07）

**时间**: 25 min
**目标**: 从不可逆边界出发，为错题本设计 Engine

#### Step 1：创建 stages.md

创建 `engine/stages.md`：

```markdown
# Delivery Engine — Stages

## 阶段序列
EVALUATE → PLAN → BUILD → VERIFY

## Stage: EVALUATE
**目的**: 确保理解正确——在错误方向上跑之前停下来
**入口条件**: 有任务描述 + Knowledge 已注入
**产出物**: artifacts/evaluate-{id}.md
**出口 Gate**: G1
**预估时间**: 5-10 min

## Stage: PLAN
**目的**: 确保方案合理——在不可逆决策之前停下来想清楚
**入口条件**: G1 通过
**产出物**: artifacts/plan-{id}.md
**出口 Gate**: G2
**预估时间**: 10-20 min

## Stage: BUILD
**目的**: 按方案实现——不做方向性决策
**入口条件**: G2 通过
**产出物**: 代码 + 测试
**出口 Gate**: G3
**预估时间**: 取决于任务复杂度

## Stage: VERIFY
**目的**: 验证完成度——"主动破坏且失败"
**入口条件**: G3 通过
**产出物**: artifacts/verify-{id}.md
**出口 Gate**: G4
**预估时间**: 10-15 min
```

**判断点**：
- 你需要更多阶段吗（如独立 REVIEW）？
- 两个阶段之间找不到不可逆边界 → 考虑合并
- 一个阶段内部有不可逆决策 → 考虑拆分

#### 验证标准
- [ ] `engine/stages.md` 存在
- [ ] 至少 3 个阶段（建议 4 个）
- [ ] 每个阶段有：目的 + 入口条件 + 产出物 + 出口 Gate

---

### Lab 6：设计门禁 + Profiles（Module 08）

**时间**: 25 min
**目标**: 为每个阶段间设计 Gate + 定义任务路径

#### Step 1：创建 gates.md

创建 `engine/gates.md`：

```markdown
# Delivery Engine — Gates

## G1: EVALUATE → PLAN
**级别**: L1（AI 自查）
**判定条件**:
- [ ] artifact 存在
- [ ] AC 数量 >= 3 且可判定
- [ ] 不可逆决策已声明
**失败处理**: 原地修复
**降级路径**: 3 次失败 → L2

## G2: PLAN → BUILD
**级别**: L2（AI 互查 — devil's advocate）
**判定条件**:
- [ ] 方案覆盖所有 AC
- [ ] 风险已识别且有缓解
- [ ] 不可逆决策有 ADR 记录
- [ ] 无致命缺陷
**失败处理**: 回退 PLAN
**降级路径**: 连续 5 次通过 → L1

## G3: BUILD → VERIFY
**级别**: L1（自动化检查）
**判定条件**:
- [ ] 代码文件存在
- [ ] 测试存在且通过
- [ ] lint 通过
- [ ] 无硬编码 secrets
**失败处理**: 原地修复；3 次同问题 → 回退 PLAN

## G4: VERIFY → Done
**级别**: L1（AI 自查）
**判定条件**:
- [ ] verify artifact 存在
- [ ] 所有 AC 有 pass/fail 标记
- [ ] 无 fail 项
- [ ] "主动破坏尝试"记录存在（>= 5 种）
**失败处理**: 回退 BUILD
```

#### Step 2：创建 profiles.md

创建 `engine/profiles.md`：

```markdown
# Delivery Engine — Profiles

## Profile: feature（默认）
**路径**: EVALUATE → PLAN → BUILD → VERIFY
**适用**: 新功能开发、重大变更

## Profile: bugfix
**路径**: EVALUATE → BUILD → VERIFY
**适用**: 已知 bug 修复（方向明确）
**Gate 调整**: G1 的 AC 要求降为 >= 1

## Profile: hotfix
**路径**: BUILD → VERIFY
**适用**: 紧急线上修复
**Gate 调整**: G3 只检查测试通过

## Profile: refactor
**路径**: PLAN → BUILD → VERIFY
**适用**: 重构（不改行为，只改结构）
**Gate 调整**: G4 要求行为不变的回归测试
```

#### Step 3：创建 STATE.md 模板

创建 `engine/STATE.md`：

```markdown
# Engine State
任务: （待填充）
Profile: （待填充）
当前阶段: （待填充）
已通过 Gates: （待填充）
开始时间: （待填充）
```

#### 验证标准
- [ ] `engine/gates.md` 有完整的 gate 定义（级别 + 判定 + 失败处理）
- [ ] `engine/profiles.md` 至少 2 个 profile
- [ ] `engine/STATE.md` 模板存在
- [ ] G2 的级别选择有理由

---

### Lab 7：SDLC 实弹 — EVALUATE + PLAN（Module 09）

**时间**: 120 min
**目标**: 跑 Engine 前半段，产出 spec artifacts，积累 corrections

#### 准备：创建 Engine SKILL.md

创建 `engine/SKILL.md`：

```markdown
---
trigger: "开始任务" OR "run engine" OR 任务下发时
---

## 执行流程
1. 读 `engine/STATE.md` 确定当前位置
2. 如果是新任务：
   a. 确定 profile（问用户或自动判断）
   b. 初始化 STATE.md
   c. 进入第一个阶段
3. 如果是续做：
   a. 读 STATE.md 确认当前阶段
   b. 继续该阶段的工作
4. 每个阶段结束时：
   a. 产出 artifact（保存到 spec/ 目录）
   b. 执行该阶段的出口 gate（读 gates.md）
   c. gate 通过 → 更新 STATE.md → 进入下一阶段
   d. gate 失败 → 执行失败处理（原地修复或回退）
```

#### 实验任务

```
用 feature profile 跑 engine。
任务：为错题本开发"拍照识别"功能。
- 用户拍照 → 上传图片 → Bedrock 识别 → 返回结构化 JSON
- 覆盖：API 设计 + 识别逻辑 + 错误处理 + 置信度判定
```

#### EVALUATE 阶段

1. 开新 session，下发任务
2. **先自己写 3 条 AC**（30 秒）——然后对比 agent 输出
3. 观察 agent 是否：
   - 读了 PRODUCT.md
   - AC 是否可判定
   - 是否识别了不可逆决策
4. 等 agent 产出 evaluate artifact
5. 跑 G1 检查

**产出**：`spec/recognize/evaluate.md`

#### PLAN 阶段

1. G1 通过后进入 PLAN
2. 观察 agent 是否参考 TECH.md 的 ADR
3. 检查方案：
   - 每个 AC 有实现映射？
   - 不可逆决策有 ADR 格式？
   - 风险识别完整？
4. 跑 G2（devil's advocate 或人工审查）

**产出**：`spec/recognize/plan.md`

#### 验证标准
- [ ] `spec/recognize/evaluate.md` 存在，含 AC + 风险 + 不可逆决策
- [ ] `spec/recognize/plan.md` 存在，含方案 + ADR + 风险
- [ ] STATE.md 更新为 "当前: BUILD, G1✅ G2✅"
- [ ] TECH.md 可能新增了 ADR
- [ ] corrections.log 新增了若干条

---

### Lab 8：SDLC 实弹 — BUILD + VERIFY（Module 10）

**时间**: 120 min
**目标**: 跑 Engine 后半段，产出代码，体验 BUILD-VERIFY 循环

#### BUILD 阶段

1. G2 通过后进入 BUILD
2. 关键约束：**BUILD 不做方向性决策**
3. 观察 agent 是否：
   - 参考了 plan.md
   - 遵循 TECH.md 约束
   - 同时写代码和测试
4. **允许 agent 犯错**——纠正并记录
5. 跑 G3（测试通过 + lint + 无 secrets）

**常见偏差**（让它犯再纠正）：
- 偏离方案、过度工程、跳过测试
- 忽略错误处理、硬编码
- 不参考 DDD

#### VERIFY 阶段

1. G3 通过后进入 VERIFY
2. Agent 应做"主动破坏"：
   - 空图片、超大图片、非图片文件
   - Bedrock 超时、返回异常
   - 至少 5 种破坏尝试
3. 产出 verify artifact
4. 跑 G4

**预期**：G4 第一次大概率 FAIL → 回退 BUILD 修复 → 再 VERIFY

#### 产出
- 代码实现 + 测试
- `spec/recognize/verify.md`
- STATE.md 更新为 DONE
- corrections.log 大幅增长

#### Mini 蒸馏（15 min）

Lab 结束前快速做：
1. 打开 corrections.log
2. 按类型分组（完成度/方案/引用/格式）
3. 标记 top-3 patterns
4. 如果发现明显的 coverage gap → 更新 governance

---

## Day 3 — 验证 + 蒸馏 + Loop + Capstone

---

### Lab 9：验证工程 + Eval（Module 11）

**时间**: 30 min
**目标**: 设计 Behavioral Contract + 业务验证脚本

#### Step 1：创建 Behavioral Contract

创建 `eval/golden-set.md`：

```markdown
# Behavioral Contract — AgentOS 行为测试

## 完成度行为
- IF agent 声称完成一个功能
  THEN verify artifact 必须存在
  AND 至少 5 种破坏尝试有记录
  AND 所有 AC 有 pass/fail 标记

## Engine 遵循
- IF 任务类型是 feature
  THEN 必须经过 EVALUATE → PLAN → BUILD → VERIFY
  AND 每阶段有对应 artifact
  AND STATE.md 记录全部 gate 通过

## Principles 引用
- IF agent 做了设计决策
  THEN 决策必须记录在 ADR 中

## Gate 效果
- IF G3 检查测试
  THEN 提交的代码测试必须通过

## 蒸馏方向
- IF corrections.log 有 3+ 条同类 correction
  THEN governance/ 中应有对应 rule 或 principle
```

#### Step 2：创建 Eval 脚本

创建 `eval/run-eval.sh`：

```bash
#!/bin/bash
# AgentOS 行为验证

AGENTOS_DIR="$(dirname "$(dirname "$0")")"
PASS=0
FAIL=0

echo "=== AgentOS Behavioral Eval ==="

# 1. 完成度检查
echo ""
echo "Completion Behavior:"
for verify in $(find "$AGENTOS_DIR/spec" -name "verify*" 2>/dev/null); do
  ATTEMPTS=$(grep -c "破坏\|边界\|异常\|failure\|error" "$verify" 2>/dev/null || echo 0)
  if [ "$ATTEMPTS" -ge 5 ]; then
    echo "  PASS $verify: $ATTEMPTS attempts"
    PASS=$((PASS + 1))
  else
    echo "  FAIL $verify: only $ATTEMPTS (need >=5)"
    FAIL=$((FAIL + 1))
  fi
done

# 2. Engine 遵循检查
echo ""
echo "Engine Compliance:"
if [ -f "$AGENTOS_DIR/engine/STATE.md" ]; then
  if grep -q "G1" "$AGENTOS_DIR/engine/STATE.md" && grep -q "G2" "$AGENTOS_DIR/engine/STATE.md"; then
    echo "  PASS Feature flow gates recorded"
    PASS=$((PASS + 1))
  else
    echo "  FAIL Missing gate records"
    FAIL=$((FAIL + 1))
  fi
else
  echo "  FAIL No STATE.md"
  FAIL=$((FAIL + 1))
fi

# 3. Governance 覆盖
echo ""
echo "Governance Coverage:"
PRINCIPLE_COUNT=$(grep -c "^## P" "$AGENTOS_DIR/governance/principles.md" 2>/dev/null || echo 0)
if [ "$PRINCIPLE_COUNT" -ge 3 ]; then
  echo "  PASS $PRINCIPLE_COUNT principles"
  PASS=$((PASS + 1))
else
  echo "  FAIL Need >=3 principles (have $PRINCIPLE_COUNT)"
  FAIL=$((FAIL + 1))
fi

# 4. 蒸馏健康
echo ""
echo "Distillation Health:"
ACTIVE=$(find "$AGENTOS_DIR/governance/rules" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
if [ "$ACTIVE" -le 15 ]; then
  echo "  PASS Rule count healthy ($ACTIVE)"
  PASS=$((PASS + 1))
else
  echo "  FAIL Too many rules ($ACTIVE)"
  FAIL=$((FAIL + 1))
fi

# Summary
echo ""
echo "=== Summary ==="
TOTAL=$((PASS + FAIL))
echo "  Pass: $PASS | Fail: $FAIL | Total: $TOTAL"
if [ "$TOTAL" -gt 0 ]; then
  SCORE=$((PASS * 100 / TOTAL))
  echo "  Score: ${SCORE}%"
fi
```

```bash
chmod +x eval/run-eval.sh
```

#### Step 3：创建业务验证脚本

创建 `ci/verify.sh`：

```bash
#!/bin/bash
# 业务验证：检查识别功能的输出 schema

echo "=== Business Verification ==="

# Schema 检查（根据实际代码路径调整）
echo "Schema verification: (configure after BUILD)"
echo "  - confidence field: [0, 1]"
echo "  - question_text: non-empty string"
echo "  - knowledge_points: array"

echo ""
echo "Run with actual code:"
echo "  python -c \"from recognize import recognize; ...\""
```

```bash
chmod +x ci/verify.sh
```

#### Step 4：运行 Eval

```bash
bash eval/run-eval.sh
```

#### 验证标准
- [ ] `eval/golden-set.md` 有 5+ 条行为契约
- [ ] `eval/run-eval.sh` 可执行且输出得分
- [ ] `ci/verify.sh` 存在
- [ ] 知道当前得分和差距方向

---

### Lab 10：蒸馏工坊（Module 11b）

**时间**: 25 min
**目标**: 从 corrections 中蒸馏，让 governance 文件变短

#### Step 1：记录蒸馏前快照

```bash
wc -l governance/principles.md governance/rules/*.md 2>/dev/null
# 记下总行数: ___
```

#### Step 2：Pattern 识别（8 min）

1. 打开 `corrections.log`
2. 给每条打标签：
   - 格式遗漏类
   - 深度不足类
   - 流程跳步类
   - 引用缺失类
3. 找到 >= 3 条的 cluster
4. 写下该 cluster 的"一句话根因"：___

#### Step 3：执行蒸馏（12 min）

选择招式：

**招式一：上提（Rules → Principle）**
- 信号：3+ 条 rules 追溯到同一根因
- 动作：写/强化 principle，移动 rules 到 `_retired/`

**招式二：下沉（Rule → Gate）**
- 信号：某 rule 被违反 3+ 次
- 动作：变成 gate 脚本，移动 rule 到 `_retired/`

**招式三：毕业（Gate 不触发）**
- 信号：某 gate 从未触发
- 动作：标记为毕业候选

退休 rule 时标注原因：
```markdown
<!-- RETIRED: 被 Principle P1 吸收 (2024-01-17) -->
```

#### Step 4：验证（5 min）

```bash
# 蒸馏后快照
wc -l governance/principles.md governance/rules/*.md 2>/dev/null
# 行数减少了？___

# 跑 eval 确认 score 没降
bash eval/run-eval.sh
```

#### 验证标准
- [ ] governance 总行数 <= 蒸馏前
- [ ] `_retired/` 目录有退休的 rule 文件
- [ ] eval score 没有下降
- [ ] 退休的 rule 标注了退休原因

---

### Lab 11：Loop Engineering（Module 12）

**时间**: 20 min
**目标**: 为 Engine 配置 Loop 运行条件

#### Step 1：创建 Loop 配置

创建 `engine/loop-config.md`：

```markdown
# Loop Configuration

## 停止条件（满足任一即停）
- goal_achieved: G4 通过（所有 AC pass）
- timeout: 60 min per task
- cost_cap: $5 per task
- max_gate_retries: 同一 gate 失败 5 次
- eval_threshold: eval score >= 80%

## 熔断条件（立即中断 + 等人）
- infinite_loop: 连续 3 次相同 gate 失败 pattern
- cost_spike: >10K tokens/min 持续 3 min
- destructive_action: rm -rf / permission change / data delete
- api_failure: 连续 5 次 API 异常

## 成本治理
- budget_per_task: $5
- budget_per_session: $20
- efficiency_alert: >15K tokens/AC

## 升级策略（什么时候找人）
- gate_fail_3x: 同一 gate 连续 3 次失败 → notify
- architecture_decision: PLAN 阶段的 ADR → 等待审批
- new_error_type: 从未见过的 correction 类别 → notify
```

#### Step 2：更新 gates.md 的降级路径

为每个 gate 标注当前级别和降级条件：

```markdown
**当前级别**: L2
**降级条件**: 连续 5 次通过 → 降为 L1
**升级条件**: 连续 3 次失败 → 升为 L3
```

#### 思考题
- 你回去后第一个放进 loop 的任务类型是什么？（建议：bugfix）
- 什么任务你永远不会放进 loop？（建议：架构选型、数据迁移）

#### 验证标准
- [ ] `engine/loop-config.md` 有停止条件 + 熔断 + 成本 + 升级策略
- [ ] gates.md 每个 gate 有当前级别和降级条件

---

### Lab 12：Capstone 整合（Module 13）

**时间**: 45 min
**目标**: 整合为完整 repo + README + 最终 Eval

#### Step 1：结构补全（15 min）

对照最终结构检查：

```
my-agentos/
├── README.md                    ← 待写
├── knowledge/
│   ├── PRODUCT.md               ✓
│   ├── TECH.md                  ✓
│   ├── IMPROVEMENT.md           ✓
│   ├── PROJECT.md               ✓
│   └── health.sh               ✓
├── governance/
│   ├── principles.md            ✓
│   ├── rules/                   ✓
│   │   ├── R001-*.md
│   │   └── _retired/
│   └── gates/                   ✓
│       ├── check-*.sh
│       └── _graduated/
├── engine/
│   ├── SKILL.md                 ✓
│   ├── stages.md                ✓
│   ├── gates.md                 ✓
│   ├── profiles.md              ✓
│   ├── STATE.md                 ✓
│   └── loop-config.md           ✓
├── eval/
│   ├── golden-set.md            ✓
│   └── run-eval.sh             ✓
├── hooks/
│   ├── on-session-start.sh     ✓
│   └── on-session-end.sh       ✓
├── spec/                        ✓
│   └── recognize/
├── corrections.log              ✓
├── ci/
│   └── verify.sh               ✓
└── docs/
    └── 30-60-90-action-plan.md  ← 待写
```

补缺失的文件，确保 hooks 注册到 settings.json。

#### Step 2：编写 README.md（15 min）

```markdown
# My AgentOS

## 是什么
[一句话：你的 AgentOS 核心理念]

## 核心 Principles
1. [P1]
2. [P2]
3. [P3]

## 使用方式
1. 克隆此 repo 到项目根目录
2. 配置 hooks: `cp .claude/settings.json <project>/.claude/`
3. 启动 session — Knowledge 自动注入
4. 下发任务 — 触发 Engine SKILL

## 健康检查
```bash
bash knowledge/health.sh
```

## 行为验证
```bash
bash eval/run-eval.sh
```

## Engine 使用
- feature: EVALUATE → PLAN → BUILD → VERIFY
- bugfix: EVALUATE → BUILD → VERIFY
- hotfix: BUILD → VERIFY

## 蒸馏节奏
- 每积累 10-15 条 corrections 做一次蒸馏
- 目标：governance 文件变短，覆盖变广
```

#### Step 3：最终 Eval + Git Commit（15 min）

```bash
# 跑最终 eval
bash eval/run-eval.sh

# 记录得分: ___

# Git commit
git add -A
git commit -m "AgentOS v1.0 - Initial release"
```

#### Step 4：编写 30/60/90 行动计划

创建 `docs/30-60-90-action-plan.md`：

```markdown
# 30/60/90 Action Plan

## 30 Days: 运行 + 积累
- [ ] 将 AgentOS 接入项目 [___]
- [ ] 跑 3 个 feature 通过 Engine
- [ ] 积累 50+ corrections
- [ ] 做 2 次蒸馏
- [ ] 每周 eval 追踪 score
**成功指标**: principles <= 5, rules 有退休记录

## 60 Days: 渐进 + Loop
- [ ] G1/G3 降为 L1
- [ ] 第一次 bugfix loop 实验
- [ ] PROJECT.md 自动更新
- [ ] Eval score 上升趋势
**成功指标**: 至少 1 类任务可 loop

## 90 Days: 进化 + 迁移
- [ ] AgentOS 接入第二个项目
- [ ] 跨项目 Principles 复用
- [ ] Governance 总量 < Day 30 的 70%
**成功指标**: 新项目接入 < 1 天

## 明天第一件事
[___]
```

---

## 互评 Checklist

互评时使用以下维度：

| 维度 | 检查方法 |
|------|---------|
| **Principles 可判定性** | 对每条做"反例测试"——能否想到无法判断"做没做到"的场景？ |
| **Gates 合理性** | 级别是否合适？全 L3 太重？全 L1 太轻？ |
| **覆盖度** | 随机抽 3 条 correction——能追溯到哪条 principle？ |
| **蒸馏度** | rules 数量合理？有退休记录？governance 行数 vs corrections 数量？ |
| **差异点** | 最大差异是什么？为什么不同？有没有想借鉴的设计？ |

---

## 快速参考

### 三层治理模型

```
Principles（3-5 条，覆盖类）
    ↕ 上提 / 精炼
Rules（有限，可追溯，可过期）
    ↕ 下沉 / 退休
Gates（最少，代码阻断，可毕业）
```

### 蒸馏三招

| 招式 | 信号 | 动作 |
|------|------|------|
| 上提 | 3+ rules 同根因 | 写 principle，退休 rules |
| 下沉 | rule 违反 3+ 次 | 变 gate，退休 rule |
| 毕业 | gate 30天未触发 | 移入 _graduated/ |

### 健康信号

| 健康 | 生病 |
|------|------|
| 文件变短 + 质量提升 | 文件持续膨胀 |
| Gate 触发趋零 | 每个新错都需要新 gate |
| 新错首次处理对 | 同一偏差换皮重复 |
| Rules 有退休 | Rules 只加不减 |

### Gate 级别

| 级别 | 谁判定 | 适用 |
|------|--------|------|
| L1 | AI 自查 | 格式、数量等可自动检查的 |
| L2 | AI 互查 | 方案合理性、代码质量 |
| L3 | 人审批 | 不可逆决策 |

### 渐进放权路径

```
Week 1: 你看着跑（L3 为主）
Week 2: G1/G3 降为 L1，G2 保留 L2
Week 3: G2 降为 L1，ADR 审批保留 L3
Week 4+: 全 L1 + 异常时升级
```
