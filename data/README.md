# data/ — 实验前数据配置（已就位）

> 本目录保存 zxcvbn-MoonBit 移植所需的全部上游数据与证据。生成脚本在 `../tools/`。

## 目录内容

```
data/
├── README.md                              # 本文件
└── upstream/
    ├── dropbox-zxcvbn.tar.gz              # 上游原版快照（master, 2024-08-19 最后 push）
    ├── dropbox-zxcvbn/                    # 解包（已裁减）：源码 + 词典 + 官方向量
    │   ├── LICENSE.txt                    # MIT, (c) Dropbox, Inc.
    │   ├── src/*.coffee                   # 7 个源文件（matching/scoring/time_estimates/feedback/adjacency_graphs/frequency_lists/main）
    │   ├── src/frequency_lists.coffee     # ★ 上游运行时真正加载的词典（本项目的嵌入源）
    │   ├── data/*.txt                     # 6 个原始频次文件（未过滤，见下方警告）
    │   ├── data-scripts/*.py|.coffee      # 上游造词典/键盘图的脚本（provenance）
    │   └── test/test-matching.coffee      # 官方向量：10 个 test 块
    │       test/test-scoring.coffee       # 官方向量：12 个 test 块
    └── zxcvbn-rs.tar.gz                   # Rust 移植快照（master, 2026-06-01）
        zxcvbn-rs/                         # 解包：结构参考 + 差分对拍基准
            └── src/matching/mod.rs        # 1596 行，8 个匹配器的 Rust 实现
```

## ⚠️ 数据源必须用 frequency_lists.coffee，不是 data/*.txt（2026-09-23 修正）

**曾经嵌错过的版本**：最初直接嵌了 `data/*.txt` 的全文（47023/100000/4275/1219/88799/39070，
共 280,386 词）。这是错的——txt 是**未过滤的原始频次文件**，上游 `data-scripts/build_frequency_lists.py`
在生成 `src/frequency_lists.coffee` 之前对它做了四道处理：

| 处理 | 规则 | 效果（原文注释） |
| --- | --- | --- |
| 跨词典去重 | 同一 token 只保留在 **rank 最小**的那个词典 | 如 `michael/james/thomas` 从 passwords/surnames 移到 male_names |
| 短稀词剔除 | `rank >= 10**len(token)` 即删除 | 如 `sex`（passwords rank 4018，10³=1000 ≤ 4018）被剔除 |
| 逗号/双引号剔除 | 含 `,` 或 `"` 的 token 删除（comma-join 限制） | 如维基词 `ps8,000` |
| 按上限截断 | `DICTIONARIES` 上限：us_tv_and_film/english_wikipedia/passwords=30000、surnames=10000，male/female 不截断 | passwords 截到第 30000 词 `geekboy` 为止 |

**过滤后的 6 表规模（= coffee = zxcvbn-rs，逐词一致）**：

| 词典 | 词数 | 说明 |
| --- | --- | --- |
| `passwords` | 30,000 | 触顶截断；最后一个是 `geekboy` |
| `english_wikipedia` | 30,000 | 触顶截断 |
| `female_names` | 3,712 | 未触顶（raw 4275，过滤后 3712） |
| `male_names` | 983 | 未触顶（raw 1219） |
| `surnames` | 10,000 | 触顶截断 |
| `us_tv_and_film` | 19,160 | 未触顶（raw 39070，过滤后远低于 30000 上限） |
| **合计** | **93,855** | vs 原始 txt 的 280,386 |

**为什么必须用过滤后的**：`scoring.coffee` 的 `dictionary_guesses` 以 rank 为 base_guesses 基础，
rank 差 1，guesses 就差。用未过滤 txt 会让**几乎所有词典词的 rank 改变**，官方向量与
zxcvbn-rs 差分对拍在数学上不可能通过（DoD 明确要求 guesses 精确一致）。

## 数据如何进入 MoonBit

```
data/upstream/dropbox-zxcvbn/src/frequency_lists.coffee
   └─ python3 tools/gen_dictionaries.py
        ├─ 断言 coffee 与 zxcvbn-rs/src/frequency_lists.rs 常量逐词一致（双源互证）
        ├─ 断言 6 表规模 = 30000/30000/3712/983/10000/19160
        └─ ../frequency_data.mbt   （961.8 KB，26 个 const 块 + 6 个 list 解析函数）
             └─ ../frequency_lists.mbt（build_ranked_dict + Lazy rank 表 + ranked_lookup）
```

**已验证**（2026-09-23，moon 0.1.20260920）：

- `moon check`：0 错误（961.8 KB 数据、26 chunks；修正前是 2.7 MB / 73 chunks）
- `moon test`：5/5 通过——词表规模（防回归到原始 txt 的数字）、首尾词序、
  跨表去重语义、短稀词剔除语义、Regex POSIX 类
- 多行字符串用 MoonBit 官方 `#|` 行前缀语法（原始内容零转义）

## 注意事项

1. `dropbox-zxcvbn/` 与 `zxcvbn-rs/` 是**只读参考**，不要改动；`data/upstream/*.tar.gz`
   是原始下载存档（已 gitignore，不入库），解包副本仅保留被引用的文件
   （src/data/test/data-scripts/LICENSE，demo/dist 等第三方杂物已裁掉）。
2. 上游 `frequency_lists.coffee` 停留在 2017-10-13 的数据；`recent_year` 正则上游是
   `19\d\d|200\d|201\d`，**已过期**（认不出 2026），按 zxcvbn-rs 的做法更新为 `19\d\d|20\d\d`。
   此差异写入了 `docs/implementation-plan.md` 第五节。
3. 词典体积是 wasm 包大小的主要来源；修正后嵌入数据 961.8 KB（原 2.7 MB），
   MVP 直接嵌入，产物体积数据待 Phase 3（D11）测量。
