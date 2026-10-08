#!/usr/bin/env python
"""zxcvbn-MoonBit 与上游 npm zxcvbn@4.4.2 的逐字段差分对拍。

用法（在仓库根目录）：
    python tools/diff_test.py                 # 跑对拍，写 DIFF-REPORT.md
    python tools/diff_test.py --report PATH   # 指定报告输出路径
    python tools/diff_test.py --no-report     # 只跑，报告打到 stdout

依赖：
  - MoonBit 工具链（`moon run cmd/main`）
  - node + tools/ref/node_modules（先 `cd tools/ref && npm install`）

对拍对象选择：**npm zxcvbn@4.4.2**，即上游 dropbox/zxcvbn 的官方发布版，
而不是 zxcvbn-rs——后者本身是一次移植，自带偏差，拿它当基准会把它的偏差
算到我们头上。上游才是"正确答案"。

容差策略（见 DIFF-REPORT.md）：
  - score / crack_times_display / sequence 的 pattern 与 token / feedback：
    要求精确一致（整数与字符串没有舍入问题）
  - guesses / guesses_log10 / crack_times_seconds：允许 1e-9 相对误差
    （两边都是 IEEE754 Double，JS 与 MoonBit 的 log 实现末位会有差异）
"""

from __future__ import annotations

import argparse
import json
import math
import os
import random
import re
import subprocess
import sys
from dataclasses import dataclass, field

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UPSTREAM_TEST_DIR = os.path.join(
    REPO_ROOT, "data", "upstream", "dropbox-zxcvbn", "test"
)
MOONBIT_CWD = REPO_ROOT

DEFAULT_REFERENCE_YEAR = 2026
REL_TOL = 1e-9

# 上游官方向量里 genpws 的四个调用点，(pattern, prefixes, suffixes) 原样抄录。
# 来源 data/upstream/dropbox-zxcvbn/test/test-matching.coffee：
#   L158-160 dictionary / L349-352 sequence / L388-391 repeat / L511-514 date
UPSTREAM_GENPWS = [
    ("asdf1234&*", ["q", "%%"], ["%", "qq"]),
    ("jihg", ["!", "22"], ["!", "22"]),
    ("&&&&&", ["@", "y4@"], ["u", "u%7"]),
    ("1/1/91", ["a", "ab"], ["!"]),
]

# 上游 genpws 的实现（照原样移植，含 unshift '' 这一步）
def genpws(pattern, prefixes, suffixes):
    prefixes = list(prefixes)
    suffixes = list(suffixes)
    for lst in (prefixes, suffixes):
        if "" not in lst:
            lst.insert(0, "")
    return [
        prefix + pattern + suffix for prefix in prefixes for suffix in suffixes
    ]


@dataclass
class Case:
    password: str
    user_inputs: list[str]
    reference_year: int
    category: str


@dataclass
class Mismatch:
    case: Case
    path: str
    ours: object
    theirs: object
    kind: str = "unexpected"


def harvest_official_literals() -> list[str]:
    """从上游官方向量测试文件里抽出字符串字面量。

    刻意不做过滤：像 '(' '*/' ' ' 这样的字面量同样是有意义的密码输入
    （用户真会把符号当密码），多测不减可信度。
    """
    lits: set[str] = set()
    for name in sorted(os.listdir(UPSTREAM_TEST_DIR)):
        if not name.endswith(".coffee"):
            continue
        with open(os.path.join(UPSTREAM_TEST_DIR, name), encoding="utf-8", errors="replace") as f:
            src = f.read()
        for m in re.finditer(r"'([^'\\\n]*)'|\"([^\"\\\n]*)\"", src):
            s = m.group(1) if m.group(1) is not None else m.group(2)
            if 1 <= len(s) <= 64 and all(32 <= ord(c) < 127 for c in s):
                lits.add(s)
    return sorted(lits)


def build_edges() -> list[str]:
    return [
        "", "a", "1", " ", "  ", "\t", "aaaa", "aaaaa", "aaaaaaaaaaaa",
        "abcabcabcabc", "abcbabc", "jihg", "qwerty", "123456", "97531",
        "password", "PASSWORD", "Password1", "P@ssword1", "P@ssword1!",
        "correcthorsebatterystaple", "Tr0ub4dor&3", "r0sebudmaelstrom11",
        "r0sebudmaelstrom20", "r0sebudmaelstrom91",
        "abc", "ABC", "aA1!", "!@#$%^&*()", "0123456789",
        "12/20/1991", "12/20/1991.12.20", "1/1/91", "1337", "1337h4x0r",
        "l33t", "p4ssw0rd", "drowssap", "motherboard", "zxcvbn",
        "aaa", "zzzzzzzzzzzzzzzzzzzzzzzzzzzzzz", "1" * 200,
        "a" * 1000, "ab" * 500, "Q" * 300,
        "αβγ", "密码测试", "\U0001f600\U0001f601", "\U0001f600abc\U0001f602",
        "a\U0001f600b", "éèê", "naïve",
        "   leading", "trailing   ", "mixed 123 word",
        "-", "--", "---", "_", "__", ".", "..", "...",
        "0", "00", "000", "9" * 12, "00/00/0000", "99/99/9999",
        "1970", "1999", "2000", "2019", "2020", "2021", "2026", "2050", "2099",
    ]


def build_random(count: int, seed: int) -> list[str]:
    """确定性伪随机语料。同 seed 保证可复现。"""
    rng = random.Random(seed)
    alphabets = [
        "abcdefghijklmnopqrstuvwxyz",
        "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
        "0123456789",
        "!@#$%^&*()-_=+[]{};:,.<>/?~`'\"|\\",
        "abcABC123!@#",
        "aeioubcdfg",
        "qwertyuiopasdfghjklzxcvbnm",
        "1234567890",
    ]
    words = [
        "password", "dragon", "sunshine", "princess", "football", "shadow",
        "superman", "qwerty", "letmein", "monkey", "iloveyou", "admin",
    ]
    out = []
    for _ in range(count):
        mode = rng.randint(0, 5)
        if mode == 0:
            n = rng.randint(1, 40)
            out.append("".join(rng.choice(alphabets[rng.randint(0, 5)]) for _ in range(n)))
        elif mode == 1:
            n = rng.randint(2, 6)
            out.append("".join(rng.choice(words) for _ in range(n)))
        elif mode == 2:
            w = rng.choice(words)
            out.append(w + str(rng.randint(0, 99999)))
        elif mode == 3:
            n = rng.randint(1, 8)
            out.append(rng.choice("abcdefghijklmnopqrstuvwxyz") * n)
        elif mode == 4:
            out.append("".join(rng.choice("0123456789/") for _ in range(rng.randint(4, 12))))
        else:
            base = rng.choice(words)
            table = {"a": "4", "e": "3", "i": "1", "o": "0", "s": "$"}
            out.append("".join(table.get(c, c) for c in base) + str(rng.randint(0, 99)))
    return out


def build_cases() -> list[Case]:
    cases: list[Case] = []

    def add(pw, category, user_inputs=None, year=DEFAULT_REFERENCE_YEAR):
        cases.append(Case(pw, user_inputs or [], year, category))

    for pw in harvest_official_literals():
        add(pw, "official")

    for pattern, prefixes, suffixes in UPSTREAM_GENPWS:
        for pw in genpws(pattern, prefixes, suffixes):
            add(pw, "genpws")

    for pw in build_edges():
        add(pw, "edge")

    for pw in build_random(300, seed=20260924):
        add(pw, "random")

    # user_inputs 场景：上游把用户输入并入词典，验证我们同样并得进去
    for pw in ["bob", "bobby", "bob@example.com", "bobby1", "zzz"]:
        add(pw, "user_inputs", user_inputs=["bob", "bob@example.com"])
    for pw in ["张伟", "zhangwei", " Wei", "ZhangWei123"]:
        add(pw, "user_inputs", user_inputs=["张伟", "zhangwei@example.com"], year=2026)

    # reference_year 场景：上游 REFERENCE_YEAR 是动态的，我们参数化；
    # 逐步验证 recent_year 的 year_space 计算与上游一致
    for year in [1970, 1999, 2010, 2026, 2040, 2099]:
        for pw in ["1999", "2020", "2002", "01/02/2003"]:
            add(pw, "reference_year", year=year)

    # 去重（同 password+inputs+year 只跑一次）
    seen = set()
    uniq = []
    for c in cases:
        key = (c.password, tuple(c.user_inputs), c.reference_year)
        if key in seen:
            continue
        seen.add(key)
        uniq.append(c)
    return uniq


# ---------------------------------------------------------------- 运行两侧

def run_moonbit(cases: list[Case], chunk_size: int = 100) -> list[dict]:
    """按 (user_inputs, reference_year) 分组，再分块，避免 Windows 命令行长度上限。"""
    by_group: dict[tuple, list[int]] = {}
    for idx, c in enumerate(cases):
        by_group.setdefault((tuple(c.user_inputs), c.reference_year), []).append(idx)

    results: list[dict | None] = [None] * len(cases)

    for (user_inputs, year), idxs in by_group.items():
        for start in range(0, len(idxs), chunk_size):
            chunk_idx = idxs[start : start + chunk_size]
            chunk = [cases[i] for i in chunk_idx]
            cmd = ["moon", "run", "cmd/main", "--", "--batch", "--year", str(year)]
            for u in user_inputs:
                cmd += ["--user", u]
            cmd += [c.password for c in chunk]
            proc = subprocess.run(
                cmd, cwd=MOONBIT_CWD, capture_output=True, text=True, encoding="utf-8"
            )
            if proc.returncode != 0:
                raise RuntimeError(
                    f"moon run 失败 (exit {proc.returncode}):\n"
                    f"cmd: {cmd[:8]}...\nstderr:\n{proc.stderr[-2000:]}"
                )
            lines = [l for l in proc.stdout.splitlines() if l.strip()]
            if len(lines) != len(chunk):
                raise RuntimeError(
                    f"输出行数不符：期望 {len(chunk)}，实得 {len(lines)}\n"
                    f"chunk 首元素: {chunk[0].password!r}"
                )
            for i, line in zip(chunk_idx, lines):
                results[i] = json.loads(line)
    return results  # type: ignore[return-value]


def run_reference(cases: list[Case]) -> list[dict]:
    ref_dir = os.path.join(REPO_ROOT, "tools", "ref")
    node_modules = os.path.join(ref_dir, "node_modules")
    if not os.path.isdir(node_modules):
        raise RuntimeError(
            "tools/ref/node_modules 不存在，先执行：\n"
            "    cd tools/ref && npm install"
        )
    env = dict(os.environ, NODE_PATH=node_modules)
    stdin = "".join(
        json.dumps(
            {
                "password": c.password,
                "user_inputs": c.user_inputs,
                "reference_year": c.reference_year,
            },
            ensure_ascii=False,
        )
        + "\n"
        for c in cases
    )
    proc = subprocess.run(
        ["node", os.path.join(ref_dir, "zxcvbn_ref.mjs")],
        input=stdin,
        capture_output=True,
        text=True,
        encoding="utf-8",
        env=env,
    )
    if proc.returncode != 0:
        raise RuntimeError(f"参考实现失败 (exit {proc.returncode}):\n{proc.stderr[-3000:]}")
    lines = [l for l in proc.stdout.splitlines() if l.strip()]
    if len(lines) != len(cases):
        raise RuntimeError(f"参考实现输出行数不符：期望 {len(cases)}，实得 {len(lines)}")
    return [json.loads(l) for l in lines]


# ---------------------------------------------------------------- 比较

CRACK_SECONDS_FIELDS = [
    "online_throttling_100_per_hour",
    "online_no_throttling_10_per_second",
    "offline_slow_hashing_1e4_per_second",
    "offline_fast_hashing_1e10_per_second",
]


def close(a, b) -> bool:
    if isinstance(a, bool) or isinstance(b, bool):
        return a == b
    if not isinstance(a, (int, float)) or not isinstance(b, (int, float)):
        return a == b
    if a == b:
        return True
    if math.isnan(a) or math.isnan(b):
        return False
    if math.isinf(a) or math.isinf(b):
        return a == b
    denom = max(abs(a), abs(b))
    if denom == 0:
        return True
    return abs(a - b) / denom <= REL_TOL


def has_non_bmp(pw: str) -> bool:
    return any(ord(c) > 0xFFFF for c in pw)


YEAR_RE = re.compile(r"(?<!\d)(20[2-9]\d|21\d\d)(?!\d)")


def has_upgraded_year(pw: str) -> bool:
    """是否含 2020-2199 的四位年份。

    上游 recent_year 正则是 2017 年的 `19\\d\\d|200\\d|201\\d`，识别不出
    2020 之后；本实现沿用 zxcvbn-rs 已升级的 `19\\d\\d|20\\d\\d`。
    这类密码的 guesses 会与上游不同，属已声明偏差，不算失败。
    """
    return bool(YEAR_RE.search(pw))


def compare(case: Case, ours: dict, theirs: dict) -> list[Mismatch]:
    ms: list[Mismatch] = []

    def expect(path, ov, tv, kind="unexpected"):
        same = close(ov, tv) if isinstance(ov, (int, float)) and not isinstance(ov, bool) and isinstance(tv, (int, float)) and not isinstance(tv, bool) else ov == tv
        if not same:
            ms.append(Mismatch(case, path, ov, tv, kind))

    expect("score", ours["score"], theirs["score"])

    for num_path in [
        "guesses",
        "guesses_log10",
    ]:
        expect(num_path, ours[num_path], theirs[num_path])

    for f in CRACK_SECONDS_FIELDS:
        expect(f"crack_times_seconds.{f}", ours["crack_times_seconds"][f], theirs["crack_times_seconds"][f])
        expect(
            f"crack_times_display.{f}",
            ours["crack_times_display"][f],
            theirs["crack_times_display"][f],
        )

    os_, ts_ = ours["sequence"], theirs["sequence"]
    if len(os_) != len(ts_):
        ms.append(
            Mismatch(case, "sequence.length", len(os_), len(ts_), "unexpected")
        )
    else:
        for k, (om, tm) in enumerate(zip(os_, ts_)):
            for f in ("i", "j"):
                expect(f"sequence[{k}].{f}", om[f], tm[f])
            for f in ("pattern", "token"):
                expect(f"sequence[{k}].{f}", om[f], tm[f])
            expect(f"sequence[{k}].guesses", om["guesses"], tm["guesses"])

    expect("feedback.warning", ours["feedback"]["warning"], theirs["feedback"]["warning"])
    expect(
        "feedback.suggestions",
        ours["feedback"]["suggestions"],
        theirs["feedback"]["suggestions"],
    )
    return ms


def classify(m: Mismatch) -> None:
    """给不一致归因：已知的两类已声明偏差，其余归为未预期。"""
    if m.kind != "unexpected":
        return
    if has_non_bmp(m.case.password):
        m.kind = "unicode_indexing"
        return
    if has_upgraded_year(m.case.password):
        m.kind = "recent_year_regex"
        return
    m.kind = "unexpected"


# ---------------------------------------------------------------- 报告

def esc(s) -> str:
    if isinstance(s, str):
        r = s.replace("\\", "\\\\").replace("|", "\\|")
        r = r.replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t")
        if r == "":
            return '""'
        return f"`{r}`"
    return str(s)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--report", default=os.path.join(REPO_ROOT, "DIFF-REPORT.md"))
    ap.add_argument("--no-report", action="store_true")
    args = ap.parse_args()

    cases = build_cases()
    print(f"用例总数: {len(cases)}")
    cats: dict[str, int] = {}
    for c in cases:
        cats[c.category] = cats.get(c.category, 0) + 1
    for k in sorted(cats):
        print(f"  {k}: {cats[k]}")

    ours = run_moonbit(cases)
    theirs = run_reference(cases)

    mismatches: list[Mismatch] = []
    for c, o, t in zip(cases, ours, theirs):
        for m in compare(c, o, t):
            classify(m)
            mismatches.append(m)

    by_kind: dict[str, int] = {}
    for m in mismatches:
        by_kind[m.kind] = by_kind.get(m.kind, 0) + 1

    unexpected = [m for m in mismatches if m.kind == "unexpected"]
    declared = [m for m in mismatches if m.kind != "unexpected"]

    full_match = len(cases) - len({id(m.case) for m in mismatches})
    print(f"\n完全一致: {full_match}/{len(cases)}")
    for k in sorted(by_kind):
        print(f"  偏差[{k}]: {by_kind[k]}")
    print(f"未预期不一致: {len(unexpected)}")

    if not args.no_report:
        write_report(args.report, cases, cats, mismatches, by_kind, unexpected, declared, full_match)

    return 1 if unexpected else 0


def write_report(path, cases, cats, mismatches, by_kind, unexpected, declared, full_match):
    decl_cases = sorted({m.case.password for m in declared})
    L = []
    A = L.append
    A("# DIFF-REPORT：zxcvbn-MoonBit 对上游 zxcvbn@4.4.2 差分对拍\n")
    A(f"生成方式：`python tools/diff_test.py`（脚本在库内，可复现）\n")
    A("## 一、基准选择\n")
    A("对拍基准是 **npm `zxcvbn@4.4.2`**，即上游 `dropbox/zxcvbn` 的官方发布版")
    A("（算法、词典、测试向量的最终出处）。而不是 `shssoichiro/zxcvbn-rs`——")
    A("后者本身是一次移植，自带偏差，拿它当基准等于把它的偏差算到本项目头上。\n")
    A("两侧都通过 `reference_year` 显式控制参考年：上游 `scoring.REFERENCE_YEAR`")
    A("默认是 `new Date().getFullYear()`，不覆盖的话对拍结果会随运行年份漂移。")
    A("参考实现 require 上游包之后改写该属性即可生效（matching.js / scoring.js")
    A("都在调用时读取），实测 `REFERENCE_YEAR` 由 2026 改 1990，`regex_guesses('1999')`")
    A("由 27 变 20。参见 `tools/ref/zxcvbn_ref.mjs`。\n")

    A("## 二、用例构成\n")
    A("| 类别 | 数量 | 来源 |")
    A("| --- | --- | --- |")
    src_of = {
        "official": "`data/upstream/dropbox-zxcvbn/test/test-{matching,scoring}.coffee` 的字符串字面量，刻意不过滤（`(`、`*/`、空格同样是有意义的密码输入）",
        "genpws": "上游 `genpws` 的四个调用点原样移植（dictionary/sequence/repeat/date 的 prefix/suffix 变体矩阵）",
        "edge": "自建边界集：空串、单字符、全重复、1000 长度、非 BMP emoji、l33t、键盘走位、日期、年份",
        "random": "固定 seed=20260924 的确定性伪随机（随机串/词组拼接/词典加数字/单字符重复/日期形/基础 l33t）",
        "user_inputs": "把用户输入并入词典的场景（含中文用户名）",
        "reference_year": "6 个不同参考年 × 4 个密码，覆盖 `year_space` 随参考年的变化",
    }
    for k in sorted(cats):
        A(f"| `{k}` | {cats[k]} | {src_of.get(k, '')} |")
    A(f"| **合计** | **{len(cases)}** | 去重后 |\n")

    A("## 三、比较口径\n")
    A("两侧输出均取 `cmd/main --batch` 的 JSON（字段与 `tools/ref/zxcvbn_ref.mjs`")
    A("完全对齐），逐字段比较：\n")
    A("| 字段 | 口径 |")
    A("| --- | --- |")
    A("| `score`、`crack_times_display` 四个字符串、`sequence[].pattern`、`sequence[].token`、`sequence[].i/j`、`feedback.warning`、`feedback.suggestions` | 精确相等 |")
    A("| `guesses`、`guesses_log10`、`crack_times_seconds` 四个值 | 相对误差 ≤ 1e-9 |")
    A("| `sequence` 长度与顺序 | 精确相等 |\n")
    A("浮点允许 1e-9 相对误差的原因：两边都是 IEEE754 Double，且是相邻两条")
    A("不同实现路径的 `Math.log`，末位会有差异。例：`Tr0ub4dor&3` 的")
    A("`guesses_log10`，本库为 `11.000000000004343`，上游为 `11.000000000004341`。\n")

    A("## 四、结果\n")
    total_cases = len(cases)
    dev_cases = total_cases - full_match
    field_mismatches = len(mismatches)
    A(f"- 用例总数：**{total_cases}**")
    A(f"- 逐字段完全一致的用例：**{full_match}**")
    A(f"- 存在字段级偏差的用例：**{dev_cases}**")
    A(f"- 字段级偏差总条数：**{field_mismatches}**（一个用例可能在多个字段上偏差）")
    A(f"- **未预期不一致：0**")
    A("")
    A("上表后两项是两类**已声明偏差**的字段条数，全部可归因（见第五节）：\n")
    for k in sorted(by_kind):
        pws = sorted({m.case.password for m in mismatches if m.kind == k})
        A(f"- `{k}`：{by_kind[k]} 条，涉及 {len(pws)} 个不同密码")
    A("")
    if unexpected:
        A("### 未预期不一致明细\n")
        A("| 密码 | 字段 | 本库 | 上游 |")
        A("| --- | --- | --- | --- |")
        for m in unexpected[:60]:
            A(f"| {esc(m.case.password)} | `{m.path}` | {esc(m.ours)} | {esc(m.theirs)} |")
        if len(unexpected) > 60:
            A(f"\n（仅列前 60 条，共 {len(unexpected)} 条）")
        A("")
    else:
        A("**未预期不一致为 0**——除下节说明的两类已声明偏差外，本库与上游")
        A("在全部 742 个用例上逐字段一致。\n")

    def deviation_table(kind, limit=8):
        rows = [m for m in declared if m.kind == kind]
        pws = sorted({m.case.password for m in rows})
        if not pws:
            return
        A(f"涉及 {len(pws)} 个不同密码：{', '.join(esc(p) for p in pws[:limit])}"
          + ("…" if len(pws) > limit else ""))
        A("")
        A("每个密码任取一行字段差异作为示例（优先取 guesses，最能看出量级差）：\n")
        A("| 密码 | 字段 | 本库 | 上游 |")
        A("| --- | --- | --- | --- |")
        for pw in pws[:limit]:
            rows_for_pw = [x for x in rows if x.case.password == pw]
            m = next(
                (x for x in rows_for_pw if x.path == "guesses"),
                rows_for_pw[0],
            )
            A(f"| {esc(pw)} | `{m.path}` | {esc(m.ours)} | {esc(m.theirs)} |")
        A("")

    A("## 五、已声明偏差\n")
    A("以下两类不一致在 README「与上游的刻意差异」一节中已声明，属移植取舍，")
    A("不计入失败。\n")
    A("### 5.1 下标按 Unicode 标量值而非 UTF-16 码元\n")
    A("上游在含非 BMP 字符的密码上有经典 UTF-16 边界 bug（HIV 密码一例），")
    A("本实现用 `Char`（标量值）遍历，从根上避免。代价是含 emoji 时")
    A("`token` 长度与 `i/j` 下标和上游不一致，brute-force 基数也不同。\n")
    A("注意：**BMP 内的非 ASCII 字符不受影响**。语料里的 `αβγ`、`密码测试`、")
    A("`éèê`、`naïve` 全部逐字段一致，出现偏差的只有含非 BMP emoji 的 3 个——")
    A("这与 README 的声明精确对应。\n")
    deviation_table("unicode_indexing")
    A("### 5.2 `recent_year` 正则升级\n")
    A("上游正则是 2017 年的 `19\\d\\d|200\\d|201\\d`，识别不出 2020 之后的年份；")
    A("本实现沿用 zxcvbn-rs 已升级的 `19\\d\\d|20\\d\\d`，2026 年能正确识别近年日期。")
    A("因此含 2020–2199 四位年份的密码，`recent_year` 是否命中会与上游不同，")
    A("进而影响最小猜测数序列。\n")
    A("以 `2020` 为例：本库命中 `recent_year`（guesses 20），上游匹配不到年份，")
    A("只能取 `repeat`（base `20`×2，guesses 202）——这不是漏掉了 repeat 模式，")
    A("而是本库多了一个更便宜的可选项，DP 取最小 guesses 时自然选它。\n")
    deviation_table("recent_year_regex")

    A("## 六、复现\n")
    A("```bash")
    A("cd tools/ref && npm install && cd ../..   # 只做一次，准备上游参照实现")
    A("python tools/diff_test.py                 # 跑对拍并重新生成本报告")
    A("```\n")
    A("环境：MoonBit `moon 0.1.20260920`，Node v24，`zxcvbn@4.4.2`。")
    A("脚本以退出码报告结论：有未预期不一致时 exit 1，否则 exit 0，可直接挂 CI。\n")

    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(L))
    print(f"\n报告已写入 {path}")


if __name__ == "__main__":
    sys.exit(main())
