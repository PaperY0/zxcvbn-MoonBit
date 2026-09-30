// zxcvbn CLI：对一个密码给出完整的强度评估。
//
// 用法：
// ```bash
// moon run cmd/main -- "Tr0ub4dor&3"
// moon run cmd/main -- --user bob --user bob@example.com "Tr0ub4dor&3"
// moon run cmd/main -- --year 2017 --json "password"
// ```

///|
fn main {
  let args = @env.args()
  if args.length() <= 1 {
    println(
      "usage: moon run cmd/main -- [--user <word>]... [--year <n>] [--json] <password>",
    )
  } else {
    run(args)
  }
}

///|
/// 解析后的命令行选项。
struct CliOptions {
  password : String?
  user_inputs : Array[String]
  json : Bool
  reference_year : Int
}

///|
/// 从 `args`（含 argv[0]）里解析选项。第一个不以 `--` 开头、且不是选项取值的
/// 参数就是密码——这样 `--json --user bob "pw"` 也能正确工作。
fn parse_options(args : Array[String]) -> CliOptions {
  let user_inputs : Array[String] = []
  let mut json_mode = false
  let mut reference_year = 2026
  let mut password : String? = None
  let mut i = 1
  while i < args.length() {
    let arg = args[i]
    match arg {
      "--json" => {
        json_mode = true
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
      _ =>
        if password is None {
          password = Some(arg)
          i += 1
        } else {
          i += 1
        }
    }
  }
  { password, user_inputs, json: json_mode, reference_year, }
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
  match opts.password {
    Some(password) => {
      let result = @lib.zxcvbn(
        password,
        opts.user_inputs,
        reference_year=opts.reference_year,
      )
      if opts.json {
        print_json(result)
      } else {
        print_human(result)
      }
    }
    None =>
      println(
        "usage: moon run cmd/main -- [--user <word>]... [--year <n>] [--json] <password>",
      )
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
fn json_string(s : String) -> String {
  "\"" + s.replace(old="\\", new="\\\\").replace(old="\"", new="\\\"") + "\""
}
