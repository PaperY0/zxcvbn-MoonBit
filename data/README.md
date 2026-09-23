# data/ — 实验前数据配置（已就位）

> 本目录保存 zxcvbn-MoonBit 移植所需的全部上游数据与证据。生成脚本在 `../tools/`。

## 目录内容

```
data/
├── README.md                              # 本文件
└── upstream/
    ├── dropbox-zxcvbn.tar.gz              # 上游原版快照（master, 2024-08-19 最后 push）
    ├── dropbox-zxcvbn/                    # 解包：源码 + 词典 + 官方向量
    │   ├── LICENSE.txt                    # MIT, (c) Dropbox, Inc.
    │   ├── src/*.coffee                   # 7 个源文件（matching/scoring/time_estimates/feedback/adjacency_graphs/frequency_lists/main）
    │   ├── data/*.txt                     # 6 个频率词典（共 280,386 词条）
    │   └── test/test-matching.coffee      # 官方向量：10 个 test 块
    │       test/test-scoring.coffee       # 官方向量：12 个 test 块
    └── zxcvbn-rs.tar.gz                   # Rust 移植快照（master, 2026-06-01）
        zxcvbn-rs/                         # 解包：结构参考 + 差分对拍基准
            └── src/matching/mod.rs        # 1596 行，8 个匹配器的 Rust 实现
```

## 词典数据清单（license: MIT, © Dropbox, Inc.）

| 文件 | 词条数 | 格式 | rank 语义 |
| --- | --- | --- | --- |
| `passwords.txt` | 47,023 | `词 频次` | 行序（最常见密码排第一：123456→1, password→2） |
| `english_wikipedia.txt` | 100,000 | `词 频次` | 行序（the→1, of→2） |
| `female_names.txt` | 4,275 | 纯词 | 行序 |
| `male_names.txt` | 1,219 | 纯词 | 行序 |
| `surnames.txt` | 88,799 | 纯词 | 行序（smith→1） |
| `us_tv_and_film.txt` | 39,070 | `词 频次` | 行序 |

**语义对齐说明**：上游 `src/frequency_lists.coffee`（由 `build_frequency_lists.py` 生成）把 6 个 txt 转成按行序 comma-join 的词表，`build_ranked_dict` 再映射 `词 → 行号+1`。本项目 `tools/gen_dictionaries.py` 复现同一语义（取每行第一列、rank=1-based 行序、重复词后者覆盖前者——与 JS 对象赋值/Rust HashMap collect 一致）。

## 数据如何进入 MoonBit

```
data/upstream/dropbox-zxcvbn/data/*.txt
   └─ python3 tools/gen_dictionaries.py
        └─ ../frequency_data.mbt   （2.7 MB，73 个 const 块 + 6 个 list 解析函数）
             └─ ../frequency_lists.mbt（build_ranked_dict + Lazy rank 表 + ranked_lookup）
```

**已验证**（2026-09-23，moon 0.1.20260920）：

- `moon check`：0 错误（2.7 MB 数据、73 chunks）
- `moon test`：5/5 通过（词表规模、顺序、rank 语义、词典识别、Regex POSIX 类）
- 多行字符串用 MoonBit 官方 `#|` 行前缀语法（原始内容零转义，`tools/gen_dictionaries.py` 顶部注释有说明）

## 注意事项

1. `dropbox-zxcvbn/` 与 `zxcvbn-rs/` 是**只读参考**，不要改动；重新生成数据前先跑 `git -C dropbox-zxcvbn status` 确认干净。
2. 上游 `data/*.txt` 停留在 2017-10-13；`recent_year` 正则上游是 `19\d\d|200\d|201\d`，**已过期**（认不出 2026），按 zxcvbn-rs 的做法更新为 `19\d\d|20\d\d`。此差异写入了 `docs/implementation-plan.md` 第五节。
3. 词典体积是 wasm 包大小的主要来源；如需控制产物体积，优先考虑运行时按需加载（发布版再评估，MVP 直接嵌入——体积数据:wasm 待 D11 测量）。
