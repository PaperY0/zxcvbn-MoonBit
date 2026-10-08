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
/// JSON 输出，供差分对拍（tools/diff_test.py）消费。
/// 手写序列化：MoonBit 的对象字面量要求所有字段同类型，这里字段类型不齐。
fn print_json(result : @lib.Entropy) -> Unit {
  let s = result.crack_times_seconds
  let d = result.crack_times_display
  let seq = result.sequence.map(m => {
    "{\"i\":\{m.start_index()},\"j\":\{m.end_index()},\"pattern\":\{json_string(m.pattern())},\"token\":\{json_string(m.token())},\"guesses\":\{m.guesses()}}"
  })
  println(
    "{" +
    "\"password\":\{json_string(result.password)}," +
    "\"guesses\":\{result.guesses}," +
    "\"guesses_log10\":\{result.guesses_log10}," +
    "\"score\":\{result.score}," +
    "\"crack_times_seconds\":{" +
    "\"online_throttling_100_per_hour\":\{s.online_throttling_100_per_hour}," +
    "\"online_no_throttling_10_per_second\":\{s.online_no_throttling_10_per_second}," +
    "\"offline_slow_hashing_1e4_per_second\":\{s.offline_slow_hashing_1e4_per_second}," +
    "\"offline_fast_hashing_1e10_per_second\":\{s.offline_fast_hashing_1e10_per_second}" +
    "}," +
    "\"crack_times_display\":{" +
    "\"online_throttling_100_per_hour\":\{json_string(d.online_throttling_100_per_hour)}," +
    "\"online_no_throttling_10_per_second\":\{json_string(d.online_no_throttling_10_per_second)}," +
    "\"offline_slow_hashing_1e4_per_second\":\{json_string(d.offline_slow_hashing_1e4_per_second)}," +
    "\"offline_fast_hashing_1e10_per_second\":\{json_string(d.offline_fast_hashing_1e10_per_second)}" +
    "}," +
    "\"sequence\":[\{seq.join(",")}]," +
    "\"feedback\":{" +
    "\"warning\":\{json_string(result.feedback.warning)}," +
    "\"suggestions\":[\{result.feedback.suggestions.map(json_string).join(",")}]" +
    "}" +
    "}",
  )
}

///|
/// 按 RFC 8259 转义字符串内容。
///
/// 注意：MoonBit 核心库的 `String::replace` 与 JS 同名方法一致，**只替换第一个**
/// 匹配；此前用链式 `replace` 转义，遇到含两个及以上引号的反馈文案（如 repeat
/// 警告 `Repeats like "aaa" are easy to guess`）会产出非法 JSON。这里改为逐字符
/// 遍历，并补齐控制字符（< 0x20）的转义。
fn json_string(s : String) -> String {
  let b = StringBuilder()
  b.write_char('"')
  for c in s {
    match c {
      '"' => {
        b.write_char('\\')
        b.write_char('"')
      }
      '\\' => {
        b.write_char('\\')
        b.write_char('\\')
      }
      '\n' => {
        b.write_char('\\')
        b.write_char('n')
      }
      '\r' => {
        b.write_char('\\')
        b.write_char('r')
      }
      '\t' => {
        b.write_char('\\')
        b.write_char('t')
      }
      '\u0008' => {
        b.write_char('\\')
        b.write_char('b')
      }
      '\u000C' => {
        b.write_char('\\')
        b.write_char('f')
      }
      _ => {
        let n = c.to_int()
        if n < 0x20 {
          b.write_string("\\u00")
          b.write_char(hex_digit(n / 16))
          b.write_char(hex_digit(n % 16))
        } else {
          b.write_char(c)
        }
      }
    }
  }
  b.write_char('"')
  b.to_string()
}

///|
fn hex_digit(n : Int) -> Char {
  if n < 10 {
    ('0'.to_int() + n).to_char().unwrap()
  } else {
    ('a'.to_int() + n - 10).to_char().unwrap()
  }
}
