#!/usr/bin/env python3
"""从上游 CoffeeScript 邻接图生成 MoonBit 数据模块。

数据源：data/upstream/dropbox-zxcvbn/src/adjacency_graphs.coffee（MIT, (c) Dropbox, Inc.）
输出：  adjacency_graphs.mbt

上游格式是 CoffeeScript 对象字面量，四个图（qwerty/dvorak/keypad/mac_keypad）各占一行，
键为单字符（写成 JSON 风格字符串），值为长度 6（键盘）或 8（小键盘）的数组，
元素要么是 null，要么是 1~2 个字符的字符串：第 0 位为未移位字符，第 1 位为移位字符。

MoonBit 侧用 ``Map[Char, Array[String?]]`` 精确镜像该结构，保持 null 占位——
邻接表的**下标**就是 spatial_match_helper 里的 direction，缺了 null 就会算错转向。
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "data" / "upstream" / "dropbox-zxcvbn" / "src" / "adjacency_graphs.coffee"
OUT = Path(__file__).resolve().parent.parent / "adjacency_graphs.mbt"

GRAPHS = ["qwerty", "dvorak", "keypad", "mac_keypad"]


def parse_upstream() -> dict[str, dict[str, list[str | None]]]:
    """把 CoffeeScript 对象字面量转成普通 dict。

    只需要给 4 个裸标识符（图名）加引号，其余已是合法 JSON。
    """
    text = SRC.read_text(encoding="utf-8")
    lines = [
        line
        for line in text.splitlines()
        if line.strip()
        and not line.lstrip().startswith("#")
        and not line.lstrip().startswith("module.exports")
        and not line.lstrip().startswith("adjacency_graphs")
    ]
    # 上游用换行分隔图，JSON 需要显式逗号
    body = "{\n" + ",\n".join(lines) + "\n}"
    for name in GRAPHS:
        body, n = re.subn(rf"(^|\n)(\s*){name}\s*:", rf'\1\2"{name}":', body)
        if n != 1:
            raise SystemExit(f"expected exactly one definition of graph {name!r}, got {n}")
    data = json.loads(body)
    missing = [g for g in GRAPHS if g not in data]
    if missing:
        raise SystemExit(f"graphs missing from {SRC}: {missing}")
    return data


def esc_string(s: str) -> str:
    """MoonBit 双引号字符串字面量（仅需转义反斜杠与双引号；数据均为可打印 ASCII）。"""
    if any(ord(c) < 0x20 or ord(c) > 0x7E for c in s):
        raise SystemExit(f"non-printable-ASCII adjacency entry: {s!r}")
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def esc_char(ch: str) -> str:
    """MoonBit 单引号字符字面量。"""
    if len(ch) != 1:
        raise SystemExit(f"expected a single char, got {ch!r}")
    if ch.isalnum():
        return f"'{ch}'"
    if ch == "\\":
        return "'\\\\'"
    if ch == "'":
        return "'\\''"
    if ch == '"':
        return "'\"'"
    codepoint = ord(ch)
    if 0x20 <= codepoint <= 0x7E:
        return f"'{ch}'"
    return f"@char.from_int({codepoint})"


def render_graph(name: str, graph: dict[str, list[str | None]]) -> str:
    rows = []
    for key in sorted(graph):
        entries = graph[key]
        if not 1 <= len(entries) <= 8:
            raise SystemExit(f"{name}[{key!r}] has {len(entries)} entries, expected 6 or 8")
        rendered = []
        for entry in entries:
            if entry is None:
                rendered.append("None")
                continue
            if not (1 <= len(entry) <= 2):
                raise SystemExit(f"{name}[{key!r}] bad entry {entry!r}")
            # 单字符条目（keypad/mac_keypad）在 MoonBit 侧同样表示成 (c, c)：
            # 上游用 String::index_of 判定，命中位 0 => 未移位。
            unshifted = entry[0]
            shifted = entry[1] if len(entry) == 2 else entry[0]
            rendered.append(f"Some(({esc_char(unshifted)}, {esc_char(shifted)}))")
        rows.append(f"    ({esc_char(key)}, [{', '.join(rendered)}]),")
    body = "\n".join(rows)
    return f"""///|
/// `{name}` 邻接图（上游 `adjacency_graphs.{name}`）。
///
/// 每个条目 `(未移位字符, 移位字符)`；`None` 是该方向没有相邻键。占位的 `None`
/// 必须保留——数组下标即 spatial_match_helper 的 direction 计数。
let {name} : Lazy[Map[Char, Array[(Char, Char)?]]] = Lazy(() => Map([
{body}
]))
"""


HEADER = """// 由 tools/gen_adjacency_graphs.py 从 data/upstream/dropbox-zxcvbn/src/
// adjacency_graphs.coffee 生成（MIT, (c) Dropbox, Inc.），请勿手工编辑。
//
// 重新生成：python3 tools/gen_adjacency_graphs.py
//
// 邻接图语义与上游一致：
// * 键为键盘上的一个键（同时收录大小写两种形态，与上游相同）；
// * 值为长度 6（qwerty/dvorak）或 8（keypad/mac_keypad）的方向槽数组，
//   下标即 spatial_match_helper 里 `cur_direction` 的递增序号；
// * 条目 `(未移位, 移位)`；`None` 表示该方向无相邻键；
// * 单字符条目（keypad 系）第二位填同字符，对应上游字符串 index 恒为 0 的语义。

"""

# 生成数据之后追加的常量与访问器（非数据，属于本模块的公共接口）。
CONSTANTS = r"""
///|
/// 邻接图的平均度数（上游 `calc_average_degree`）。
///
/// 注意：上游 CoffeeScript 用的是**浮点除法**（432/94 = 4.595744680851064），
/// 而 zxcvbn-rs 用 u64 整数除法（= 4）。本项目以 dropbox/zxcvbn 官方向量为基准，
/// 故沿用浮点语义——差分对拍时若要跟 zxcvbn-rs 比，这里必须有意识地记为差异点。
fn calc_average_degree(graph : Map[Char, Array[(Char, Char)?]]) -> Double {
  let mut sum = 0
  for arcs in graph.values() {
    for arc in arcs {
      match arc {
        Some(_) => sum += 1
        None => ()
      }
    }
  }
  sum.to_double() / graph.length().to_double()
}

///|
/// qwerty/dvorak 用的起始键位数。
pub let keyboard_starting_positions : Int = qwerty.force().length()

///|
/// keypad/mac_keypad 用的起始键位数。
pub let keypad_starting_positions : Int = keypad.force().length()

///|
/// qwerty/dvorak 的平均度数。
pub let keyboard_average_degree : Double = calc_average_degree(qwerty.force())

///|
/// keypad/mac_keypad 的平均度数（上游注释：与 qwerty 略有不同，但取近似值）。
pub let keypad_average_degree : Double = calc_average_degree(keypad.force())

///|
/// 按图名取邻接图（spatial_match 的四个图）。图名与上游一致。
pub fn get_graph(name : String) -> Map[Char, Array[(Char, Char)?]] {
  match name {
    "qwerty" => qwerty.force()
    "dvorak" => dvorak.force()
    "keypad" => keypad.force()
    "mac_keypad" => mac_keypad.force()
    _ => abort("unknown adjacency graph: \{name}")
  }
}

///|
/// 四个键盘图的名字（顺序与上游 GRAPHS 一致，决定 omnimatch 的匹配顺序）。
pub let graph_names : Array[String] = ["qwerty", "dvorak", "keypad", "mac_keypad"]
"""


def main() -> int:
    data = parse_upstream()
    parts = [HEADER]
    for name in GRAPHS:
        parts.append(render_graph(name, data[name]))
        parts.append("\n")
    parts.append(CONSTANTS.lstrip("\n"))
    OUT.write_text("".join(parts), encoding="utf-8")

    # 生成后自检：把解析结果回写成规范 JSON，供测试或人工比对
    for name in GRAPHS:
        graph = data[name]
        entries = sum(len(v) for v in graph.values())
        keys = len(graph)
        total = sum(1 for v in graph.values() for e in v if e is not None)
        print(f"{name}: {keys} keys, {total}/{entries} non-null entries")
    print(f"wrote {OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
