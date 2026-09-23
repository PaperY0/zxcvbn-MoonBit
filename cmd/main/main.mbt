///|
/// zxcvbn CLI。
///
/// 目标用法（Phase 2 实现后）：
/// ```bash
/// moon run cmd/main -- "Tr0ub4dor&3"
/// ```
/// 输出：score / guesses / log10 / 四场景破解时间 / 命中模式 / 建议。
///
/// 当前为 Phase 0 骨架：参数解析已就位，评估逻辑待 Phase 1–2 移植完成后接入。
fn main {
  let args = @env.args()
  match args {
    [_, password, ..] => {
      println("zxcvbn (moonbit) — Phase 0 skeleton")
      println("input length: \{password.length()} chars (UTF-16 code units)")
      println(
        "evaluation engine: see docs/implementation-plan.md (Phase 1–2)",
      )
    }
    _ => println("usage: moon run cmd/main -- \"<password>\"")
  }
}
