# DIFF-REPORT：zxcvbn-MoonBit 对上游 zxcvbn@4.4.2 差分对拍

生成方式：`python tools/diff_test.py`（脚本在库内，可复现）

## 一、基准选择

对拍基准是 **npm `zxcvbn@4.4.2`**，即上游 `dropbox/zxcvbn` 的官方发布版
（算法、词典、测试向量的最终出处）。而不是 `shssoichiro/zxcvbn-rs`——
后者本身是一次移植，自带偏差，拿它当基准等于把它的偏差算到本项目头上。

两侧都通过 `reference_year` 显式控制参考年：上游 `scoring.REFERENCE_YEAR`
默认是 `new Date().getFullYear()`，不覆盖的话对拍结果会随运行年份漂移。
参考实现 require 上游包之后改写该属性即可生效（matching.js / scoring.js
都在调用时读取），实测 `REFERENCE_YEAR` 由 2026 改 1990，`regex_guesses('1999')`
由 27 变 20。参见 `tools/ref/zxcvbn_ref.mjs`。

## 二、用例构成

| 类别 | 数量 | 来源 |
| --- | --- | --- |
| `edge` | 58 | 自建边界集：空串、单字符、全重复、1000 长度、非 BMP emoji、l33t、键盘走位、日期、年份 |
| `genpws` | 29 | 上游 `genpws` 的四个调用点原样移植（dictionary/sequence/repeat/date 的 prefix/suffix 变体矩阵） |
| `official` | 343 | `data/upstream/dropbox-zxcvbn/test/test-{matching,scoring}.coffee` 的字符串字面量，刻意不过滤（`(`、`*/`、空格同样是有意义的密码输入） |
| `random` | 281 | 固定 seed=20260924 的确定性伪随机（随机串/词组拼接/词典加数字/单字符重复/日期形/基础 l33t） |
| `reference_year` | 22 | 6 个不同参考年 × 4 个密码，覆盖 `year_space` 随参考年的变化 |
| `user_inputs` | 9 | 把用户输入并入词典的场景（含中文用户名） |
| **合计** | **742** | 去重后 |

## 三、比较口径

两侧输出均取 `cmd/main --batch` 的 JSON（字段与 `tools/ref/zxcvbn_ref.mjs`
完全对齐），逐字段比较：

| 字段 | 口径 |
| --- | --- |
| `score`、`crack_times_display` 四个字符串、`sequence[].pattern`、`sequence[].token`、`sequence[].i/j`、`feedback.warning`、`feedback.suggestions` | 精确相等 |
| `guesses`、`guesses_log10`、`crack_times_seconds` 四个值 | 相对误差 ≤ 1e-9 |
| `sequence` 长度与顺序 | 精确相等 |

浮点允许 1e-9 相对误差的原因：两边都是 IEEE754 Double，且是相邻两条
不同实现路径的 `Math.log`，末位会有差异。例：`Tr0ub4dor&3` 的
`guesses_log10`，本库为 `11.000000000004343`，上游为 `11.000000000004341`。

## 四、结果

- 用例总数：**742**
- 逐字段完全一致的用例：**729**
- 存在字段级偏差的用例：**13**
- 字段级偏差总条数：**163**（一个用例可能在多个字段上偏差）
- **未预期不一致：0**

上表后两项是两类**已声明偏差**的字段条数，全部可归因（见第五节）：

- `recent_year_regex`：124 条，涉及 5 个不同密码
- `unicode_indexing`：39 条，涉及 3 个不同密码

**未预期不一致为 0**——除下节说明的两类已声明偏差外，本库与上游
在全部 742 个用例上逐字段一致。

## 五、已声明偏差

以下两类不一致在 README「与上游的刻意差异」一节中已声明，属移植取舍，
不计入失败。

### 5.1 下标按 Unicode 标量值而非 UTF-16 码元

上游在含非 BMP 字符的密码上有经典 UTF-16 边界 bug（HIV 密码一例），
本实现用 `Char`（标量值）遍历，从根上避免。代价是含 emoji 时
`token` 长度与 `i/j` 下标和上游不一致，brute-force 基数也不同。

注意：**BMP 内的非 ASCII 字符不受影响**。语料里的 `αβγ`、`密码测试`、
`éèê`、`naïve` 全部逐字段一致，出现偏差的只有含非 BMP emoji 的 3 个——
这与 README 的声明精确对应。

涉及 3 个不同密码：`a😀b`, `😀abc😂`, `😀😁`

每个密码任取一行字段差异作为示例（优先取 guesses，最能看出量级差）：

| 密码 | 字段 | 本库 | 上游 |
| --- | --- | --- | --- |
| `a😀b` | `guesses` | 1001 | 10001 |
| `😀abc😂` | `guesses` | 100001 | 10000001 |
| `😀😁` | `guesses` | 53 | 10001 |

### 5.2 `recent_year` 正则升级

上游正则是 2017 年的 `19\d\d|200\d|201\d`，识别不出 2020 之后的年份；
本实现沿用 zxcvbn-rs 已升级的 `19\d\d|20\d\d`，2026 年能正确识别近年日期。
因此含 2020–2199 四位年份的密码，`recent_year` 是否命中会与上游不同，
进而影响最小猜测数序列。

以 `2020` 为例：本库命中 `recent_year`（guesses 20），上游匹配不到年份，
只能取 `repeat`（base `20`×2，guesses 202）——这不是漏掉了 repeat 模式，
而是本库多了一个更便宜的可选项，DP 取最小 guesses 时自然选它。

涉及 5 个不同密码：`2020`, `2021`, `2026`, `2050`, `2099`

每个密码任取一行字段差异作为示例（优先取 guesses，最能看出量级差）：

| 密码 | 字段 | 本库 | 上游 |
| --- | --- | --- | --- |
| `2020` | `guesses` | 21 | 203 |
| `2021` | `guesses` | 21 | 8007.346666666665 |
| `2026` | `guesses` | 21 | 7301 |
| `2050` | `guesses` | 25 | 9491 |
| `2099` | `guesses` | 74 | 7301 |

## 六、复现

```bash
cd tools/ref && npm install && cd ../..   # 只做一次，准备上游参照实现
python tools/diff_test.py                 # 跑对拍并重新生成本报告
```

环境：MoonBit `moon 0.1.20260920`，Node v24，`zxcvbn@4.4.2`。
脚本以退出码报告结论：有未预期不一致时 exit 1，否则 exit 0，可直接挂 CI。
