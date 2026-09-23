///|
/// zxcvbn CLI（Phase 0 词典探测版）。
///
/// 当前状态：评分引擎（Phase 1–2）未实现，但词典数据与查询已可用。
/// 本 CLI 展示已就绪的部分——按空格/连字符切分输入，报告每个 token 在 6 个
/// 上游频率词典中的命中与 rank。 Phase 2 收口后会输出完整的
/// score / guesses / log10 / 四场景破解时间 / 模式明细 / 建议。
///
/// 用法：
/// ```bash
/// moon run cmd/main -- "password"        # 单个 token
/// moon run cmd/main -- "correct horse"   # 多 token
/// ```
fn main {
  let args = @env.args()
  match args {
    [_, input, ..] => run(input)
    _ =>
      println(
        "usage: moon run cmd/main -- \"<password or space-separated tokens>\"",
      )
  }
}

///|
/// 词典探测主流程。
fn run(input : String) -> Unit {
  println("zxcvbn (moonbit) — Phase 0 dictionary probe")
  let chars = input.to_array()
  let mut n = 0
  for _c in chars {
    n = n + 1
  }
  println("input: \{input}")
  println("chars: \{n} (UTF-16 code units: \{input.length()})")
  for token in input.split(" ") {
    if token.length() == 0 {
      continue
    }
    let lower = token.to_owned().to_lower()
    match @lib.ranked_lookup(lower) {
      Some((dict, rank)) =>
        println("  \{token} -> hit \{dict.to_repr()} rank \{rank}")
      None => println("  \{token} -> not in any dictionary")
    }
  }
  println("scoring engine: docs/implementation-plan.md (Phase 1–2)")
}
