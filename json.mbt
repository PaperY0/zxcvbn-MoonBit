// `Entropy` 的 JSON 序列化。
//
// 为什么放在库里而不是 CLI：浏览器是本项目的主打场景（注册表单即时打分、
// 密码不回传），而 MoonBit 的 foreign_library + js 后端能把 `String` 直接
// 映射成 JS string、`Array[String]` 直接映射成 JS 数组，但结构体没有可用的
// 编组。所以 Web 侧最自然的接口就是"返回一个 JSON 字符串"。
//
// 手写序列化而不依赖 core/json：Entropy 的字段类型不齐（String / Double /
// Int / 嵌套结构体 / 枚举数组），用 derive 出来的通用序列化会产生另一套字段
// 命名，且会把 `Match` 枚举的内部表示也倒出来。这里的输出格式与
// `tools/ref/zxcvbn_ref.mjs`（上游参照实现）逐字对齐，差分对拍直接消费它。

///|
/// 把评估结果序列化成 JSON 对象字符串。
///
/// 字段顺序固定，与上游 `zxcvbn` 的 result 对象一致；`sequence` 只含
/// `i` / `j` / `pattern` / `token` / `guesses` 五个共有字段。
pub fn Entropy::to_json(self : Entropy) -> String {
  let s = self.crack_times_seconds
  let d = self.crack_times_display
  let seq = self.sequence.map(m => {
    "{\"i\":\{m.start_index()},\"j\":\{m.end_index()},\"pattern\":\{json_string(m.pattern())},\"token\":\{json_string(m.token())},\"guesses\":\{m.guesses()}}"
  })
  "{" +
  "\"password\":\{json_string(self.password)}," +
  "\"guesses\":\{self.guesses}," +
  "\"guesses_log10\":\{self.guesses_log10}," +
  "\"score\":\{self.score}," +
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
  "\"warning\":\{json_string(self.feedback.warning)}," +
  "\"suggestions\":[\{self.feedback.suggestions.map(json_string).join(",")}]" +
  "}" +
  "}"
}

///|
/// 按 RFC 8259 转义字符串内容，含首尾引号。
///
/// 注意：MoonBit 核心库的 `String::replace` 与 JS 同名方法一致，**只替换第一个**
/// 匹配；用链式 `replace` 转义，遇到含两个及以上引号的反馈文案（如 repeat
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
      '' => {
        b.write_char('\\')
        b.write_char('b')
      }
      '' => {
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
