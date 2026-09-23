# zxcvbn-MoonBit 选题详细内容与实现计划

> 项目：`wsy19/zxcvbn`（仓库目录 `zxcvbn-moonbit/`）
> 选题：将 Dropbox 开源 **zxcvbn** 密码强度估计器移植到 MoonBit
> 状态：**选题已固定**；旧候选选题（Bloom Filter / Cron / Humanize 等）已全部删除
> 查重：三轮复查（详见 `research/ecosystem-gap-zxcvbn-verified.md`、`dupcheck-result*.txt`）——**MoonBit 生态无同类库，0 重复**
> 实验前数据：**已全部配好并验证**（工具链 / 上游数据 / 项目骨架 / 词典嵌入编译运行测试 5/5 通过）
> 整理日期：2026-09-23（Asia/Shanghai）

---

## 一、选题一句话定义

输入一个密码字符串（可附带用户信息 `user_inputs`），输出 **0–4 强度分 + 熵值（guesses/log10）+ 四场景破解时间 + 命中的模式明细 + 改进建议**——即上游 zxcvbn 的完整能力，纯度计算、零 IO 依赖、可跨 wasm/wasm-gc/js/native 后端。

## 二、为什么是它（生态价值）

1. **真实需求**：注册表单、改密校验、CLI 工具、Web 应用都要评估密码强度；MoonBit 的 Web 生态（moonapi/mooncat 等）正缺这一环，纯计算库 + Wasm 后端天然适合浏览器场景（前端注册表单即时打分、密码不回传）。
2. **生态空白**：mooncakes 2622 个模块、GitHub `topic:moonbit` 全量检索 0 个 zxcvbn 实现；现存 4 个名字带"密码强度"的库（moonvault / moonpassword / strongPasswordChecker / kesmeey-tools）逐个读源码确认全部是 **LUDS 字符计数式规则打分**（长度档位+字符类别+重复扣分），没有熵、没有攻击模型、没有词典/l33t/键盘/日期/序列模式。
3. **规格清晰可验证**：上游 MIT 许可、有官方测试向量（22 个 test 块）、有强类型同范式移植（zxcvbn-rs，MIT）可差分对拍——这是评委视角的"正确性可硬验证"。
4. **12 天可交付**：纯算法、边界清晰、数据已就位（见第七节，2.7MB 词典编译运行已实测通过），主要工作量是逐模块移植 + 官方向量转写。

## 三、功能范围

### 本期做（与上游 1:1 对齐的完整闭环）

| 能力 | 上游对应 | 说明 |
| --- | --- | --- |
| 词典匹配 | `matching.coffee` `dictionary_match` | 6 个频率词典（47k 常见密码 / 100k 维基词 / 男女名 / 88k 姓氏 / 39k 影视词），取最小 guesses |
| 反向词典 | `reverse_dictionary_match` | 反转串命中（drowssap） |
| l33t 替换 | `l33t_match` + `L33T_TABLE` | a→4@、e→3、i→1!| … 17 条替换表 + 子集枚举 |
| 键盘空间 | `spatial_match` + `adjacency_graphs` | qwerty / dvorak / keypad / mac_keypad 四图，转向/位移计数 |
| 重复 | `repeat_match` | `abcabcabcabc` 的 base_token × repeat_count |
| 序列 | `sequence_match` | abc / 123 / 97531 等 26 字母/数字序列 |
| 正则 | `regex_match` | `recent_year`（年份）、`digits` 等 |
| 日期 | `date_match` | yyyy/mm/dd、dd/mm/yyyy、mm/dd/yyyy 等多格式 + 分隔符 |
| 最优序列 DP | `scoring.most_guessable_match_sequence` | 动态规划取最小 guesses 的非重叠匹配序列 |
| 猜测数估计 | `estimate_guesses` 全家 | 每模式 base guesses × 变体倍数 |
| 强度分 | `time_estimates.guesses_to_score` | 阈值 1e3 / 1e6 / 1e8 / 1e10（DELTA=5） |
| 破解时间 | `estimate_attack_times` | 在线限流 100/h、在线不限流 10/s、离线慢哈希 1e4/s、离线快哈希 1e10/s |
| 建议文案 | `feedback.coffee` | warning + suggestions（按最长匹配给建议） |

### 明确不做（写进 README 非目标）

- 多语言词典（中文词表等）——MVP 只有上游英文数据，保留词典扩展 API；
- 口令哈希/校验（用 `moonbitlang/x/bcrypt`，互补不重造）；
- 分布式破解模拟、Web 服务器、完整 UI 组件（只提供一个 Wasm 演示页）；
- Unicode 密码的高级 Grapheme 处理（MVP 按 Unicode 标量值遍历，边界在 README 声明）。

## 四、上游参考实现与许可证（已逐个核实）

| 项目 | ★ | License | 用途 |
| --- | --- | --- | --- |
| `dropbox/zxcvbn` | 16060 | MIT | 上游原版（CoffeeScript，源码 + 6 个词典 txt + 22 个官方向量 test 块） |
| `shssoichiro/zxcvbn-rs` | 273 | MIT | Rust 移植，**首选结构参考**（强类型 enum + per-pattern struct，6045 行） |

二者已下载至 `data/upstream/`（见 `data/README.md`）。本项目 MIT 发布，LICENSE 与 README 保留 Dropbox 版权声明与移植来源，测试向量同样标注来源。

## 五、架构设计

```
wsy19/zxcvbn（单包，多文件；moon.mod name = wsy19/zxcvbn）
├── zxcvbn.mbt            # 公共 API：pub fn zxcvbn(password, user_inputs) -> Entropy
├── matching.mbt          # omnimatch：8 个匹配器 + 工具（translate/mod/sorted）
├── scoring.mbt           # most_guessable_match_sequence DP + 各模式 guesses + nCk/log
├── time_estimates.mbt    # 四场景破解时间 + guesses_to_score + display_time
├── feedback.mbt          # warning/suggestions
├── adjacency_graphs.mbt  # qwerty/dvorak/keypad/mac_keypad 邻接图（从上游移植）
├── frequency_lists.mbt   # Dictionary 枚举 + build_ranked_dict + 惰性 rank 表（已写好）
├── frequency_data.mbt    # 【生成文件】6 词典嵌入数据（tools/gen_dictionaries.py）
├── cmd/main/main.mbt     # CLI：moon run cmd/main -- "password"
└── *_test.mbt            # 白盒/黑盒测试 + 官方向量
```

数据流（与上游 `main.coffee` 一致，但去掉全局状态）：
```
zxcvbn(pw, user_inputs)
  → user_dict = build_ranked_dict(sanitize(user_inputs))   // 每次调用新建，无全局态
  → matches = omnimatch(pw, user_dict)                     // 8 匹配器全量跑
  → result = most_guessable_match_sequence(pw, matches)    // DP 最小 guesses
  → crack_times + score = estimate(result.guesses)
  → feedback = get_feedback(score, sequence)
```

**与上游的刻意差异（都是改进，README 里声明）**：
1. 上游 `set_user_input_dictionary` 用模块级全局变量，MoonBit 版改为调用时传入（纯函数、无竞态、可重入）；
2. 上游 `REFERENCE_YEAR = new Date().getFullYear()`（运行时可变），MoonBit core 无时钟 API，改为 `zxcvbn(pw, inputs, reference_year?=2026)` 参数化默认值——同时让测试完全确定；
3. 上游正则 `19\d\d|200\d|201\d`（2017 年数据）在 Rust 移植里已更新为 `19\d\d|20\d\d`，本项目沿用**更新后**的范围（2026 年能正确识别近年日期）。

## 六、MoonBit 实现要点（全部已实测，非推测）

| # | 事实 | 来源/验证 | 对移植的影响 |
| --- | --- | --- | --- |
| 1 | **多行字符串 = 每行 `#|` 前缀**（`#|` 原始内容零转义，`$|` 支持转义/插值） | 官方文档 language/fundamentals + 本目录 `/tmp/mbt-test` 实测通过 | 词典嵌入无需转义，反斜杠/引号/保留字安全 |
| 2 | **core 的 Regex 不支持 `\d \w \s`**，须用 POSIX 类 `[[:digit:]]`（ASCII 语义） | 官方文档 fundamentals 第 "String#" 正则小节 | 上游 `\d` 正则全部改写；`^`/`$` 是非多行锚点（够用） |
| 3 | **`String` 是 UTF-16 code unit 序列**；`String::length()` 与 `s[i]` 都是码元粒度 | core/builtin/string_methods.mbt 注释原文 + research 报告 3.1 节 | **必须按字符遍历**（`for c in password` / `password.to_array()`），否则复刻 moonvault 的 emoji 长度 bug（BMP 外字符算 2 长度、代理码元被判"特殊字符"） |
| 4 | `Lazy::Lazy(thunk)` + `.force()`（`moonbitlang/core/lazy`） | 本机 core 源码 | 词典 rank 表惰性构建，首次 `zxcvbn()` 调用时生效 |
| 5 | Array/Map 的 `push`/`[]=` 等方法调用**不需要** `let mut`；`mut` 只在重绑定变量时需要 | `moon check` 实测（unused_mut 报错） | 照 JS 写法直接 `let m = Map([])` 后 `m[k]=v` |
| 6 | 大字符串字面量按块切分（本项目每 4000 词一个 const，共 73 块） | 2.7MB 数据 `moon check`/`moon test` 5/5 通过 | 词典数据按 chunk 嵌入，避免单节点过大 |
| 7 | 工具链版本 `moon 0.1.20260920`，`moon new` 生成 moon.mod/moon.pkg 新版布局 | 本机已安装（`~/.moon/bin`） | 按新布局组织；CI 固定该版本 |
| 8 | `inspect(x, content=)` 断言用 Debug 格式（字符串不带引号） | moon test 实测 | 测试断言写法注意格式 |
| 9 | `StringView::to_string()` 已废弃，用 `to_owned()` | moon check 警告 | 从 StringView 建 owned String 用 `to_owned()` |

## 七、实验前数据配置（✅ 已完成并验证）

| 项 | 状态 | 证据 |
| --- | --- | --- |
| MoonBit 工具链 | ✅ 已装（`~/.moon/bin`，v0.1.20260920） | `moon version --all` |
| `moon update` + `moon search zxcvbn` | ✅ 官方注册表 0 模块 | `dupcheck-result6.txt` 末节 |
| 上游 dropbox/zxcvbn + zxcvbn-rs 源码/数据 | ✅ 已下载解包 | `data/upstream/`（含 MIT LICENSE） |
| 词典生成脚本 | ✅ `tools/gen_dictionaries.py`（读 txt → `#|` 多行字符串 + 解析函数） | 6 词典 47023/100000/4275/1219/88799/39070 词 |
| 数据嵌入编译 | ✅ `moon check` 0 错误（2.7MB / 73 chunks） | 实测 |
| rank 语义/查找测试 | ✅ `moon test` **5/5 通过**（词表规模、顺序、rank、词典识别、Regex POSIX 类） | 实测 |

## 八、实现步骤（完整路线图，按上游文件逐个移植）

> 标注 ✅ 的为实验前已完成；其余按顺序推进，每天保持 2–4 个功能性 commit（申报要求 ≥10 个有效 commits）。

### Phase 0：立项与脚手架（9-23 当日完成）

- [x] 选题固定、旧选题删除、三轮查重 + `moon search` 官方查重
- [x] 工具链安装、上游数据下载、项目骨架 `moon new`
- [x] 词典数据嵌入 + 5 项去风险测试通过（最大不确定性已排除）
- [x] `frequency_lists.mbt`（Dictionary 枚举 / build_ranked_dict / ranked_lookup）
- [ ] README.mbt.md（一句话定义、API、3 个使用场景、非目标、查重结论、许可）
- [ ] LICENSE 保留上游版权声明；`.github/workflows/` CI（check/test 双后端）
- [ ] ≥10 个真实 commits 后 push GitHub，提交一页申报书（**截止 9-24 24:00**）

### Phase 1：纵向打通 MVP（申报后 D1–D5）

**D1 数学底座**（`scoring.mbt` 的纯函数部分）
- `log2/log10`（Double 精度与上游一致：上游用 `Math.log(x)/Math.LN2`）、`nCk`（Int 帕斯卡三角或乘法公式，注意 `nCk(0,0)=1`、`nCk(0,k>0)=0`，上游有官方向量 `[33,7,4272048]`）、`factorial`、`truncate` 辅助
- 测试：直接转写 `test-scoring.coffee` 的 `nCk`/`log` 两个 test 块（含恒等式性质测试）

**D2 匹配数据模型 + 词典匹配**
- `Match` 结构：`{ i, j, token, pattern, ...每模式字段 }`（照 zxcvbn-rs 的 per-pattern struct 拆 enum，而非 JS 的动态对象）
- `dictionary_match`：遍历 6 个 rank 表 → 所有子串查表 → 生成 `Dictionary` match（rank/dictionary_name/reversed=false/l33t=false）
- `reverse_dictionary_match`：对密码反转串再跑一遍词典匹配
- 测试：转写 `test-matching.coffee` 的 `dictionary matching` / `reverse dictionary matching` 两组向量

**D3 l33t + 空间（键盘）**
- `L33T_TABLE`（17 条）+ `relevant_l33t_subtable`（剪枝）+ `enumerate_l33t_subs`（子集枚举）+ `translate`
- `adjacency_graphs.mbt`：四张邻接图（直接从上游 `adjacency_graphs.coffee` 转录，注意 `qwerty`/`dvorak`/`keypad`/`mac_keypad` 的键位与 shifted 标记）
- `spatial_match_helper`：转向（turns）统计 + 一次移动多键的 Shifted 处理
- 测试：`l33t matching` / `spatial matching`（含 prefixes/suffixes 的 `genpws` 变体矩阵）

**D4 重复/序列/正则/日期**
- `repeat_match`（base_token 递归缩小：aaa→a、abab→ab，照上游 `repeat_match` 的 while 缩小逻辑）
- `sequence_match`（26 字母 + 10 数字两套序列空间，`sequence_space` 用于 guesses）
- `regex_match`：`recent_year`（`19\d\d|20\d\d`→`[[:digit:]]` 版）、`digits`（纯数字串）
- `date_match`：`map_ints_to_dmy` / `map_ints_to_dm` / `two_to_four_digit_year` + 分隔符识别（`- / . 空格 空`），`MIN_YEAR=1000`、`DATE_MAX_YEAR=2050` 上下界（照上游 531–599 行）
- 测试：`sequence matching` / `repeat matching` / `regex matching` / `date matching` 四组向量（上游对日期给了大量边界）

**D5 OMNIMATCH 汇总 + 排序**
- `omnimatch`：按上游顺序跑 8 个匹配器 + 用户输入词典（`UserInputs` 类型）
- `sorted`：按 `(i 升, j-i 降, guesses 升, ...)` 上游既定比较器排序（决定 DP 的输入顺序，**必须与上游一致**否则 DP 打平时选错序列）
- 测试：`matching utils`（empty/extend/translate/mod/sorted）+ omnimatch 冒烟

### Phase 2：评分与输出（D6–D8）

**D6 最优序列 DP**
- `most_guessable_match_sequence`：上游 DP（`up_to_k` 参数，k=5 时只保留长度 ≤5 的候选跳过——HIV 密码 UTF-16 边界的历史 bug 修复；MoonBit 按字符遍历后仍保留该参数保语义一致）
- `brute_force_cardinality`：按字符类别（lower/upper/digit/symbol/unicode）算池大小
- 测试：`most guessable match sequence` test 块 + score=0 的空序列行为

**D7 各模式 guesses**
- `estimate_guesses` 分派 + `bruteforce_guesses` / `repeat_guesses` / `sequence_guesses` / `regex_guesses` / `date_guesses` / `spatial_guesses`（含 `KEYBOARD_AVERAGE_DEGREE` 等预计算常量）/ `dictionary_guesses`（uppercase_variations + l33t_variations + rank）
- `uppercase_variations`（`START_UPPER/END_UPPER/ALL_UPPER/ALL_LOWER` 四正则 → 按 `[[:upper:]]` 等 POSIX 类改写）
- 测试：`scoring` 主 test 块的 entropy/guesses/分数断言（上游给了完整密码 → guesses/entropy/score 三元组表）

**D8 时间估算 + feedback + 公共 API 收口**
- `estimate_attack_times`（四场景）+ `display_time`（less than a second / X seconds / minutes / hours / days / months / years / centuries 分档，照上游公式）+ `guesses_to_score`
- `feedback.get_feedback` + `get_match_feedback`（按最长匹配的 pattern 分支：dictionary/spatial/repeat/sequence/date/regex/bruteforce）
- `zxcvbn()` 主函数 + `Entropy` 结果结构 + sanitize 用户输入
- 测试：`time estimates` / `feedback` 向量 + 端到端冒烟（如 `zxcvbn("password")` score=0、guesses=55893×uppercase_variations；`zxcvbn("correcthorsebatterystaple")` score=4）

### Phase 3：规格一致性与工程化（D9–D11）

**D9 差分对拍（正确性硬证据）**
- 写 `tools/diff_test.py`：取官方向量密码集 + 随机长尾集 → 同一输入分别喂本库（CLI JSON 输出）与 zxcvbn-rs（Rust 侧最小 harness，`cargo run` 输出同构 JSON）→ 逐字段 diff（score/guesses/log10/crack_times）
- 容差策略：`log10(guesses)` 与 crack_times 允许 1e-9 相对误差（Double 舍入），score/整数 guesses 要求精确一致
- 输出 `DIFF-REPORT.md`：通过率 + 任何偏差的归因（如 `REFERENCE_YEAR` 动态性、正则 `\d` 语义）

**D10 边界与极端输入**
- 空字符串、单字符、全重复、1000 长度、BMP 外 emoji（验证字符粒度）、纯符号、混合大小写 l33t、`user_inputs` 命中自身
- `moon test --enable-coverage` + `moon coverage report -f summary`，补齐核心分支
- 多后端测试：`--target wasm-gc/js/native` 至少各跑一遍

**D11 CI + 发布 + 演示**
- GitHub Actions：`moon fmt --check` / `moon check` / `moon test`（三后端矩阵）
- README 补全：安装（`moon add wsy19/zxcvbn`）、API 文档、3 个场景示例（注册表单后端 / CLI / Wasm 浏览器强度条 demo 页）、限制说明
- 发布 mooncakes.io（`moon login` → `moon publish` 或 bundle 上传），全新临时目录 `moon add` 复现安装
- `demo/`：最小 HTML + wasm 强度条（证明"MoonBit/Wasm 天然适合浏览器场景"）

### Phase 4：验收缓冲（D12）

- 只修阻断性问题；核对问卷/邮件/赛事群最终要求；保存 CI、测试报告、mooncakes 页面、DIFF-REPORT 为验收证据
- 复盘：生态修 bug 实证（moonvault 的 UTF-16 长度 bug、kesmeey/tools 的 index_of 方向 bug）写进 README "为什么必须以字符为单位"一节

## 九、测试策略（三层，全部有明确来源）

1. **官方向量**（`test-matching.coffee` 10 个 test 块 + `test-scoring.coffee` 12 个 test 块）：CoffeeScript/tape 格式，用 `genpws` 生成 prefix/suffix 变体矩阵。转写方式：Python 脚本辅助抽取 → MoonBit `inspect` 断言（第一批先手工转写 matching/scoring 各 2–3 个块，验证流程后再批量）。
2. **zxcvbn-rs 差分**（D9）：Rust 侧 20 行 harness 输出 JSON，Python 对拍，见上。这是比官方向量更强的证据（覆盖上游没有断言的组合）。
3. **性质与边界**：nCk 恒等式、无假阴性式性质（DP 结果 guesses ≤ 任何单一覆盖方案的 guesses——可对随机密码暴力验证）、字符粒度性质（emoji 密码长度按字符）。

## 十、风险与对策

| 风险 | 概率 | 对策 |
| --- | --- | --- |
| 词典嵌入编译慢/体积大 | ~~高~~ **已排除** | 实测 2.7MB / 73 chunks 编译通过、测试 5/5；如需更小体积可改为发布时裁剪子集 |
| core Regex 语义与 JS 正则差异（`\d`、锚点） | 中 | 全部改写为 POSIX 类并加针对性测试；date 匹配的上游正则逐个核对（D4） |
| UTF-16 vs 字符粒度 | 中 | 一律 `for c in password`；emoji 测试用例锁定行为（D10） |
| 排序比较器不一致导致 DP 打平选错序列 | 中 | 严格照上游 `sorted` 比较器 + 官方向量里的打平用例；差分对拍兜底 |
| `REFERENCE_YEAR` 影响 guesses（上游动态取当年） | 低 | 参数化默认 2026；差分测试固定年份，README 声明 |
| 语言 beta API 变动 | 低 | 核心逻辑与 IO/FFI 边界分离；`moon.mod` 固定工具链版本；CI 锁定 |
| 时间紧迫（截止 9-24 24:00） | **高、现实** | Phase 0 今日完成即申报（调研+数据+骨架+测试已远超"10 commits"门槛）；申报后按 Phase 1–4 继续，章程允许 Proposal 通过后启动 |

## 十一、验收标准（Definition of Done）

- [ ] `moon check` / `moon test` 0 错误，三后端（wasm-gc/js/native）全绿
- [ ] 官方向量 22 个 test 块全部转写通过
- [ ] `DIFF-REPORT.md`：与 zxcvbn-rs 在 ≥500 个输入上 score/guesses 一致（log10/crack_times 容差内）
- [ ] 覆盖率报告入库；边界用例（空/emoji/1000 长度/user_inputs）全部通过
- [ ] README 可从零复现：`moon add wsy19/zxcvbn` + 3 个场景示例 + CLI
- [ ] mooncakes.io 已发布，LICENSE 含上游版权声明
- [ ] ≥10 个有意义的 commits，CI 徽章在 README

## 十二、查重结论摘要（申报话术见 research/ecosystem-gap-zxcvbn-verified.md 第九节）

- mooncakes.io：2622 个模块全量扫描，`zxcvbn` 0 命中；官方的 `moon search zxcvbn` → **No modules found**（2026-09-23）
- GitHub：`zxcvbn moonbit` / `password strength topic:moonbit` 等 10 组检索 0 或无关；近期 `topic:moonbit` top100 无同方向
- 现有 4 个"密码强度"库逐个读源码：全部 LUDS 字符计数范式，无攻击模型/熵/模式匹配（详见查重报告第三节）
- `moonbitlang/core`（70 包）/ `x`（24 包）：无此能力，`x/bcrypt` 是互补的口令哈希
- awesome-moonbit：全部关键词 0 次
