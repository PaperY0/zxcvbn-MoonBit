// zxcvbn CLI：对一个密码给出完整的强度评估。
//
// 用法：
// ```bash
// moon run cmd/main -- "Tr0ub4dor&3"
// moon run cmd/main -- --user bob --user bob@example.com "Tr0ub4dor&3"
// moon run cmd/main -- --year 2017 --json "password"
// moon run cmd/main -- --batch "pw1" "pw2" "pw3"
// ```
//
// `--batch` 把所有位置参数都当作密码，逐个评估并输出 JSON Lines（每行一个 JSON
// 对象），供 tools/diff_test.py 差分对拍消费。批内所有密码共用同一组 `--user`
// 与 `--year`，所以需要不同 user_inputs 的用例要分开跑。

///|
fn main {
  let args = @env.args()
  if args.length() <= 1 {
    println(
      "usage: moon run cmd/main -- [--user <word>]... [--year <n>] [--json] [--batch] <password>...",
    )
  } else {
    run(args)
  }
}

///|
/// 解析后的命令行选项。
struct CliOptions {
  /// 所有不以 `--` 开头、也不是选项取值的参数；单密码模式取第一个。
  positionals : Array[String]
  user_inputs : Array[String]
  json : Bool
  /// 批模式：把每个 positionals 元素当一个密码，输出 JSON Lines。
  batch : Bool
  reference_year : Int
}

///|
/// 从 `args`（含 argv[0]）里解析选项。位置参数先统一收进 `positionals`，
/// 再由 `batch` 决定语义——这样 `--json --user bob "pw"` 与
/// `--batch a b --user bob` 都能正确工作，且选项顺序无关。
fn parse_options(args : Array[String]) -> CliOptions {
  let positionals : Array[String] = []
  let user_inputs : Array[String] = []
  let mut json_mode = false
  let mut batch_mode = false
  let mut reference_year = 2026
  let mut i = 1
  while i < args.length() {
    let arg = args[i]
    match arg {
      "--json" => {
        json_mode = true
        i += 1
      }
      "--batch" => {
        batch_mode = true
        i += 1
      }
      "--user" => {
        i += 1
        if i < args.length() {
          user_inputs.push(args[i])
          i += 1
        }
      }
      "--year" => {
        i += 1
        if i < args.length() {
          reference_year = parse_int_option(args[i], 2026)
          i += 1
        }
      }
      _ => {
        positionals.push(arg)
        i += 1
      }
    }
  }
  {
    positionals,
    user_inputs,
    json: json_mode,
    batch: batch_mode,
    reference_year,
  }
}

///|
/// 把参数解析成 Int，失败时回落默认值（避免为此依赖会 raise 的 `parse_int`）。
fn parse_int_option(s : String, fallback : Int) -> Int {
  let chars = s.to_array()
  if chars.length() == 0 {
    return fallback
  }
  let mut i = 0
  let mut negative = false
  if chars[0] == '-' {
    negative = true
    i = 1
  }
  if i >= chars.length() {
    return fallback
  }
  let mut value = 0
  while i < chars.length() {
    let c = chars[i]
    if !c.is_ascii_digit() {
      return fallback
    }
    value = value * 10 + (c.to_int() - '0'.to_int())
    i += 1
  }
  if negative {
    -value
  } else {
    value
  }
}

///|
fn run(args : Array[String]) -> Unit {
  let opts = parse_options(args)
  if opts.batch {
    if opts.positionals.is_empty() {
      println("usage: moon run cmd/main -- --batch <password>...")
    } else {
      for password in opts.positionals {
        let result = @lib.zxcvbn(
          password,
          opts.user_inputs,
          reference_year=opts.reference_year,
        )
        print_json(result)
      }
    }
  } else if opts.positionals.is_empty() {
    println(
      "usage: moon run cmd/main -- [--user <word>]... [--year <n>] [--json] [--batch] <password>...",
    )
  } else {
    let result = @lib.zxcvbn(
      opts.positionals[0],
      opts.user_inputs,
      reference_year=opts.reference_year,
    )
    if opts.json {
      print_json(result)
    } else {
      print_human(result)
    }
  }
}

///|
fn print_human(result : @lib.Entropy) -> Unit {
  println("password      : \{result.password}")
  println("guesses       : \{result.guesses}")
  println("log10(guesses): \{result.guesses_log10}")
  println("score         : \{result.score} / 4")
  let s = result.crack_times_seconds
  println("crack times (seconds):")
  println(
    "  online throttling (100/h)     : \{s.online_throttling_100_per_hour}",
  )
  println(
    "  online no throttling (10/s)   : \{s.online_no_throttling_10_per_second}",
  )
  println(
    "  offline slow hashing (1e4/s)  : \{s.offline_slow_hashing_1e4_per_second}",
  )
  println(
    "  offline fast hashing (1e10/s) : \{s.offline_fast_hashing_1e10_per_second}",
  )
  let d = result.crack_times_display
  println("crack times (display):")
  println(
    "  online throttling (100/h)     : \{d.online_throttling_100_per_hour}",
  )
  println(
    "  online no throttling (10/s)   : \{d.online_no_throttling_10_per_second}",
  )
  println(
    "  offline slow hashing (1e4/s)  : \{d.offline_slow_hashing_1e4_per_second}",
  )
  println(
    "  offline fast hashing (1e10/s) : \{d.offline_fast_hashing_1e10_per_second}",
  )
  println("matches (\{result.sequence.length()}):")
  if result.sequence.length() == 0 {
    println("  (none)")
  } else {
    for m in result.sequence {
      println(
        "  [\{m.start_index()}, \{m.end_index()}] \{m.pattern()} \{m.token()} guesses=\{m.guesses()}",
      )
    }
  }
  println("warning: \{result.feedback.warning}")
  println("suggestions:")
  for suggestion in result.feedback.suggestions {
    println("  - \{suggestion}")
  }
}

///|
/// JSON 输出，供差分对拍（tools/diff_test.py）与 Web 侧消费。
/// 序列化本身在库里（`Entropy::to_json`），这里只负责打印。
fn print_json(result : @lib.Entropy) -> Unit {
  println(result.to_json())
}
