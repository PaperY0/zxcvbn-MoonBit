# PaperY0/zxcvbn

> Dropbox [zxcvbn](https://github.com/dropbox/zxcvbn) 密码强度估计器的 MoonBit 移植。
> 输入密码字符串，输出 **0–4 强度分 + 熵值（guesses/log10）+ 四场景破解时间 + 命中的模式明细 + 改进建议**。

[![CI](https://github.com/PaperY0/zxcvbn-MoonBit/actions/workflows/ci.yml/badge.svg)](https://github.com/PaperY0/zxcvbn-MoonBit/actions/workflows/ci.yml)
[English below](#papery0zxcvbn-en)

## 为什么是它

MoonBit 生态里没有一个**攻击模型驱动**的密码强度估计器：现存 4 个名字带"密码强度"的库
（`Q30399/moonvault`、`GMH233/moonpassword`、`ZijianFeng33/strongPasswordChecker`、
`kesmeey/tools`）经逐个读源码确认，全部是 **LUDS 字符计数式规则打分**（长度档位 + 字符类别
存在性 + 重复扣分）——没有熵、没有词典、没有 l33t、没有键盘邻接、没有日期/序列/重复模式、
没有破解时间。zxcvbn 模拟真实破解器：对密码做全模式匹配后取**最小猜测数**，输出保守的强度
估计。三轮查重（mooncakes 2622 模块全量扫描 + GitHub 10 组检索 + awesome-moonbit +
官方 `moon search zxcvbn` → No modules found）确认这里是空白。

### 与 LUDS 规则打分的实证边界

这不是"算法更高级"的口号，而是可复现的**方向性错误**。下表是本库的真实输出
（`moon run cmd/main -- <password>`），LUDS 列是典型 LUDS 实现（长度档位 + 字符类别计分）
会给出的分数：

| 密码 | 典型 LUDS 打分 | 本库 zxcvbn | 真实情况 |
| --- | --- | --- | --- |
| `Password1!` | 4（4 类齐全、长度 10） | **1** | `Password` 是 rank 2 的高频词典词，大小写与符号几乎不增加成本 |
| `correcthorsebatterystaple` | 3（仅小写、无数字符号） | **4** | 4 个普通英文词、无任何模式，真正的离线破解下限是 2.7e14 次猜测 |
| `qwerty123456` | 3（长度 12、含数字） | **1** | 键盘直行（qwerty）+ 数字序列（123456），1851 次即可命中 |
| `Tr0ub4dor&3` | 4 | 4 | 确实强（1e11 次暴力破解），但这是"碰巧"，不是规则算出来的 |

LUDS 的两个系统性失败：**把"字符类别齐全"当作强度**（`Password1!`），
以及**把"只有小写字母"当作弱点**（`correcthorsebatterystaple`）。
本库的做法是枚举真实破解器会先用的东西——词典、l33t 变体、键盘走位、日期、序列、重复——
然后取最小猜测数，所以结论可以和实际抗破解能力对上。

## 能力范围

- **8 个模式匹配器**：6 个频率词典（30k 常见密码 / 30k 维基词 / 3712 女名 / 983 男名 / 10k 姓氏 / 19160 影视词，共 93,855 词）、
  反向词典、l33t 替换（17 条替换表 + 子集枚举）、键盘空间（qwerty/dvorak/keypad/mac_keypad）、
  重复（`abcabcabc`）、序列（`abc`/`123`/`97531`）、正则（年份）、日期（多格式 + 分隔符）
- **最优匹配序列 DP**：动态规划取最小 guesses 的非重叠序列
- **输出**：`guesses` / `log10(guesses)` / 0–4 分 / 四场景破解秒数（在线限流 100/h、在线
  不限流 10/s、离线慢哈希 1e4/s、离线快哈希 1e10/s）/ warning + suggestions

## API 设计

```moonbit nocheck
pub fn zxcvbn(
  password : String,
  user_inputs : Array[String],
  reference_year? : Int = 2026,
) -> Entropy

pub struct Entropy {
  password : String
  /// 保守估计的猜测次数（Double：长密码会达到 1e10^n 甚至上溢）
  guesses : Double
  /// log10(guesses)
  guesses_log10 : Double
  /// 0..4，阈值 1e3 / 1e6 / 1e8 / 1e10（与上游一致）
  score : Int
  /// 四场景破解秒数
  crack_times_seconds : CrackTimes
  /// 人类可读破解时间
  crack_times_display : CrackTimesDisplay
  /// 最优匹配序列
  sequence : Array[Match]
  feedback : Feedback
}

/// 一次模式匹配（按模式拆成 enum + 每模式 struct，仿 zxcvbn-rs 的强类型范式）
pub enum Match {
  Bruteforce(BruteforceMatch)
  Dictionary(DictionaryMatch)
  Spatial(SpatialMatch)
  Repeat(RepeatMatch)
  Sequence(SequenceMatch)
  Regex(RegexMatch)
  Date(DateMatch)
}
pub fn Match::start_index(self) -> Int    // 闭区间起点
pub fn Match::end_index(self) -> Int      // 闭区间终点
pub fn Match::token(self) -> String       // 命中的原文字符串
pub fn Match::pattern(self) -> String     // "dictionary" / "spatial" / ...
pub fn Match::guesses(self) -> Double
```

低层匹配器也可单独调用（上游签名的对应对齐，便于测试与二次封装）：

```moonbit nocheck
pub fn dictionary_match(Array<Char>, Array<(Dictionary, Map<String, Int])>, Int) -> Array<Match>
pub fn reverse_dictionary_match(Array<Char>, Array<(Dictionary, Map<String, Int])>, Int) -> Array[Match]
pub fn l33t_match(Array<Char], Array<(Dictionary, Map<String, Int])], Map<Char, Array<Char]], Int) -> Array<Match>
pub fn spatial_match(Array<Char], Array<(String, Map<Char, Array<(Char, Char)?]])>) -> Array[Match]
pub fn repeat_match(Array<Char], Array<(Dictionary, Map<String, Int])], Int, Map<Char, Array<Char]], Int) -> Array[Match]
pub fn sequence_match(Array<Char]) -> Array<Match>
pub fn regex_match(Array[Char]) -> Array<Match]
pub fn date_match(Array<Char>, Int) -> Array<Match>
```

## 三个使用场景

1. **注册/改密表单（服务端）**：`zxcvbn(pw, [username, email])` —— 用户输入参与词典，
   防止"用自己名字当密码"。
2. **CLI 工具**：`moon run cmd/main -- "Tr0ub4dor&3"` 打印分数/熵/破解时间/模式明细/建议；
   `--json` 输出机器可读结果（供差分对拍消费）。
3. **浏览器 Wasm 强度条**：MoonBit 纯计算库直接编 wasm-gc，前端注册表单即时打分，密码不回传。

## 与上游的刻意差异（都是修正，逐条说明）

1. **下标按 Unicode 标量值计，而非 UTF-16 码元。** 上游在含非 BMP 字符的密码上有过经典的
   UTF-16 边界 bug（HIV 密码一例）；本实现用 MoonBit 的 `Char`（即标量值）遍历，
   从根上避免。代价：`token` 长度与上游 `String::length()` 在含 emoji 时不同。
2. **`guesses` 用 `Double` 而非整数。** 上游 JS 全程是浮点数；长密码的 bruteforce 猜测数会
   达到 10^n 乃至上溢，用 Int 会静欲溢出。`zxcvbn-rs` 同样用 `f64`。
3. **`reference_year` 参数化（默认 2026）。** 上游取运行时当年，MoonBit core 没有时钟 API，
   故参数化——同时让测试完全确定。
4. **`recent_year` 正则升级为 `19\d\d|20\d\d`。** 上游的正则是 2017 年的 `19\d\d|200\d|201\d`，
   识别不出 2020 年之后的年份；这里沿用 zxcvbn-rs 已更新的范围。
   （附带：MoonBit core 的 Regex 不支持 `\d`，须用 POSIX 类 `[[:digit:]]`，
   而正则也没有反向引用 `\1`——所以本项目的 `repeat_match` 用手写的周期检测，
   `regex_match` 用手写的四位年扫描，两者在语义上与上游等价。）
5. **词典匹配的长度上限裁剪。** 只枚举到"所有词典中最长词条"的长度：更长的子串不可能命中，
   语义完全等价，但把词典匹配从 O(n²) 次哈希查询降到 O(n × 最长词长)。
6. **无全局状态。** 上游用模块级变量传递用户输入词典；本实现改为调用时传入，天然纯函数、
   可重入、线程安全。

## 测试策略

**53 个测试全部通过**，来源三层：

1. **上游官方向量**（`test/test-matching.coffee` 10 个块 + `test/test-scoring.coffee` 12 个块）
   逐块转写：词典/反向/l33t（含子表与子集枚举）/键盘空间/序列/重复/正则/日期/omnimatch，
   以及 nCk、log、DP 搜索、各模式 guesses、uppercase/l33t 变体。官方向量里的
   `genpws` prefix/suffix 变体矩阵也一并转写。
2. **性质与端到端**：`r0sebudmaelstrom11/20/91aaaa` 精确复现上游 omnimatch 的四大匹配；
   `correcthorsebatterystaple` → score 4。
3. **边界**：空串、单字符、纯空白、1000 长度密码、**非 BMP emoji**（验证按标量值计长）、
   `user_inputs` 命中自身、`reference_year` 参数化。

```bash
moon check   # 0 error，0 warning
moon test    # 53/53（默认 wasm 后端）

# 三个后端都全绿（验证“纯计算、无 IO 依赖”的声明）
moon test --target wasm     # 53/53
moon test --target wasm-gc  # 53/53
moon test --target js       # 53/53

moon run cmd/main -- "correct horse battery staple"
```

## 非目标（明确不做）

多语言词典、口令哈希（用 `moonbitlang/x/bcrypt`，互补）、分布式破解模拟、完整 UI 组件库、
Grapheme 级 Unicode 处理（按 Unicode 标量值遍历）。

## 开发

```bash
moon check          # 静态检查
moon info           # 更新 .mbti 接口
moon fmt            # 格式化
moon test           # 测试
moon run cmd/main -- "password"
python3 tools/gen_dictionaries.py      # 从 data/upstream 重新生成词典数据模块
python3 tools/gen_adjacency_graphs.py  # 从数据/upstream 重新生成键盘邻接图模块
# 两个生成器的产物需再跑一次 moon fmt（生成器不保证 fmt-clean，CI 的 fmt 门禁会校验）
```

## 数据与许可

- 词典数据（6 个频率表，93,855 词条）与官方向量来自 `dropbox/zxcvbn` 的
  `src/frequency_lists.coffee`（上游运行时实际加载的过滤后词典，与 zxcvbn-rs 逐词一致），
  **MIT License, (c) Dropbox, Inc.**，见 [`data/README.md`](data/README.md)。
- 结构参考 `shssoichiro/zxcvbn-rs`（MIT）。
- 本项目以 MIT 发布，LICENSE 保留上游版权声明。

## 当前状态（2026-09-30）

✅ 评分引擎完整实现（8 匹配器 + DP + 每模式 guesses + 破解时间 + 建议）·
✅ 上游 22 个官方向量 test 块全部转写通过 · ✅ 53/53 测试通过 · ✅ `moon check` 0 error / 0 warning ·
✅ CLI 输出完整结果与 JSON · ✅ 键盘邻接图数据由脚本生成（可复现）·
✅ CI：wasm / wasm-gc / js 三后端测试矩阵 + fmt/check/接口校验门禁 ·
🚧 Phase 3 剩余：`DIFF-REPORT.md` 系统性差分对拍、mooncakes 发布、demo/ wasm 演示页。

---

<a id="papery0zxcvbn-en"></a>

## PaperY0/zxcvbn (EN)

A MoonBit port of Dropbox's [zxcvbn](https://github.com/dropbox/zxcvbn) password strength
estimator: pattern-matching based (dictionaries, l33t, keyboard adjacency, dates, sequences,
repeats), minimum-guesses DP scoring, 0–4 score, crack-time estimation, and actionable
feedback. Pure computation, no IO; the wasm / wasm-gc / js targets are verified in CI
(the native target is also supported by the toolchain but not covered by CI).

```moonbit nocheck
let result = @zxcvbn.zxcvbn("Tr0ub4dor&3", ["bob", "bob@example.com"])
result.score          // 0..4
result.guesses        // conservative attack-model lower bound (Double)
result.sequence       // optimal non-overlapping matches
result.feedback       // warning + suggestions
```

Dictionary data and official test vectors are from `dropbox/zxcvbn` (MIT, (c) Dropbox, Inc.);
structural reference: `shssoichiro/zxcvbn-rs` (MIT).
