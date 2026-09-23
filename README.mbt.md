# PaperY0/zxcvbn

> Dropbox [zxcvbn](https://github.com/dropbox/zxcvbn) 密码强度估计器的 MoonBit 移植。
> 输入密码字符串，输出 **0–4 强度分 + 熵值（guesses/log10）+ 四场景破解时间 + 命中的模式明细 + 改进建议**。

[English below](#papery0zxcvbn-en)

## 为什么是它

MoonBit 生态里没有一个**攻击模型驱动**的密码强度估计器：现存 4 个名字带"密码强度"的库
（`Q30399/moonvault`、`GMH233/moonpassword`、`ZijianFeng33/strongPasswordChecker`、
`kesmeey/tools`）经逐个读源码确认，全部是 **LUDS 字符计数式规则打分**（长度档位 + 字符类别
存在性 + 重复扣分）——没有熵、没有词典、没有 l33t、没有键盘邻接、没有日期/序列/重复模式、
没有破解时间。zxcvbn 模拟真实破解器：对密码做全模式匹配后取**最小猜测数**，输出保守的强度
估计。三轮查重（mooncakes 2622 模块全量扫描 + GitHub 10 组检索 + awesome-moonbit +
官方 `moon search zxcvbn` → No modules found）确认这里是空白。

## 能力范围

- **8 个模式匹配器**：6 个频率词典（30k 常见密码 / 30k 维基词 / 3712 女名 / 983 男名 / 10k 姓氏 / 19160 影视词，共 93,855 词）、
  反向词典、l33t 替换（17 条替换表 + 子集枚举）、键盘空间（qwerty/dvorak/keypad/mac_keypad）、
  重复（`abcabcabc`）、序列（`abc`/`123`/`97531`）、正则（年份/纯数字）、日期（多格式 + 分隔符）
- **最优匹配序列 DP**：动态规划取最小 guesses 的非重叠序列
- **输出**：`guesses` / `log10(guesses)` / 0–4 分 / 四场景破解秒数（在线限流 100/h、在线
  不限流 10/s、离线慢哈希 1e4/s、离线快哈希 1e10/s）/ warning + suggestions

## API 设计（草案，Phase 2 收口）

```moonbit nocheck
pub fn zxcvbn(
  password : String,
  user_inputs : Array[String],
  reference_year? : Int = 2026,
) -> Entropy

pub struct Entropy {
  guesses : Int            // 估计猜测次数（保守下限）
  guesses_log10 : Double   // log10(guesses)
  score : Int              // 0..4，阈值 1e3 / 1e6 / 1e8 / 1e10（与上游一致）
  crack_times_seconds : CrackTimes      // 四场景
  crack_times_display : CrackTimes      // 人类可读
  sequence : Array[Match]  // 最优匹配序列（每项含 pattern/token/i/j/guesses）
  feedback : Feedback      // warning + suggestions
}
```

## 三个使用场景

1. **注册/改密表单（服务端）**：`zxcvbn(pw, [username, email])` —— 用户输入参与词典，
   防止"用自己名字当密码"。
2. **CLI 工具**：`moon run cmd/main -- "Tr0ub4dor&3"` 打印分数/熵/破解时间/建议。
3. **浏览器 Wasm 强度条**：MoonBit 纯计算库直接编 wasm-gc，前端注册表单即时打分，密码不回传。

## 非目标（明确不做）

多语言词典、口令哈希（用 `moonbitlang/x/bcrypt`，互补）、分布式破解模拟、完整 UI 组件库、
Grapheme 级 Unicode 处理（MVP 按 Unicode 标量值遍历）。

## 测试策略

上游官方测试向量（22 个 test 块，MIT）逐块转写 + 与 zxcvbn-rs 差分对拍 + 性质/边界测试
（空串/emoji/1000 长度/user_inputs）。详见
[`docs/implementation-plan.md`](docs/implementation-plan.md)。

## 开发

```bash
moon check          # 静态检查
moon test           # 测试（含词典数据 5 项去风险测试）
moon run cmd/main -- "password"
python3 tools/gen_dictionaries.py   # 从 data/upstream 重新生成词典数据模块
```

## 数据与许可

- 词典数据（6 个频率表，93,855 词条）与官方向量来自 `dropbox/zxcvbn` 的
  `src/frequency_lists.coffee`（上游运行时实际加载的过滤后词典，与 zxcvbn-rs 逐词一致），
  **MIT License, (c) Dropbox, Inc.**，见 [`data/README.md`](data/README.md)。
- 结构参考 `shssoichiro/zxcvbn-rs`（MIT）。
- 本项目以 MIT 发布，LICENSE 保留上游版权声明。

## 当前状态（2026-09-23）

✅ 工具链就绪（moon 0.1.20260920）· ✅ 词典嵌入编译通过（961.8 KB / 26 chunks，
数据源为上游过滤后的 frequency_lists.coffee，与 zxcvbn-rs 逐词一致）· ✅ 测试 5/5 通过 ·
✅ CLI 词典探测可用（`moon run cmd/main -- "correct horse battery"`）·
🚧 Phase 0 完成，Phase 1（数学底座 + 词典匹配）待开工。

---

<a id="papery0zxcvbn-en"></a>

## PaperY0/zxcvbn (EN)

A MoonBit port of Dropbox's [zxcvbn](https://github.com/dropbox/zxcvbn) password strength
estimator: pattern-matching based (dictionaries, l33t, keyboard adjacency, dates, sequences,
repeats), minimum-guesses DP scoring, 0–4 score, crack-time estimation, and actionable
feedback. Pure computation, no IO, compiles to wasm / wasm-gc / js / native.

Dictionary data and official test vectors are from `dropbox/zxcvbn` (MIT, (c) Dropbox, Inc.);
structural reference: `shssoichiro/zxcvbn-rs` (MIT).
