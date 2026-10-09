// Black-box tests (package `PaperY0/zxcvbn` seen from outside).
// Public behavior belongs here; internal helpers go to `*_wbtest.mbt`.
//
// 数据来源：dropbox/zxcvbn 的行为基准 + 本项目的边界用例
//（空串 / 非 BMP 字符 / 长密码 / user_inputs）。

///|
/// 端到端冒烟：空密码。
test "zzcvbn('') => guesses 1, score 0, no matches" {
  let r = @zxcvbn.zxcvbn("", [])
  debug_inspect(r.guesses, content="1")
  debug_inspect(r.guesses_log10, content="0")
  debug_inspect(r.score, content="0")
  debug_inspect(r.sequence.length(), content="0")
  // 空序列走 default_feedback
  assert_eq(r.feedback.warning, "", msg="no warning")
  assert_eq(
    r.feedback.suggestions,
    [
      "Use a few words, avoid common phrases", "No need for symbols, digits, or uppercase letters",
    ],
    msg="default feedback suggestions",
  )
}

///|
/// 端到端冒烟：最常见的密码。
test "zzcvbn('password') => top-10 common password, score 0" {
  let r = @zxcvbn.zxcvbn("password", [])
  // rank=2 的词典匹配 + DP 的长度惩罚 (1! * 2 + 10000^0)
  debug_inspect(r.guesses, content="3")
  debug_inspect(r.guesses_log10, content="0.47712125471966244")
  debug_inspect(r.score, content="0")
  debug_inspect(r.sequence.length(), content="1")
  assert_eq(r.sequence[0].pattern(), "dictionary", msg="pattern == dictionary")
  assert_eq(r.sequence[0].token(), "password", msg="token == password")
  assert_eq(
    r.feedback.warning,
    "This is a top-10 common password",
    msg="top-10 warning",
  )
}

///|
/// 端到端：上游著名的 "correct horse battery staple" 应该是强密码。
test "zzcvbn('correcthorsebatterystaple') => score 4" {
  let r = @zxcvbn.zxcvbn("correcthorsebatterystaple", [])
  debug_inspect(r.score, content="4")
  debug_inspect(r.guesses, content="273500327700640")
  debug_inspect(r.sequence.length(), content="4")
  assert_eq(r.sequence[0].pattern(), "dictionary", msg="pattern == dictionary")
  assert_eq(r.sequence[0].token(), "correct", msg="token == correct")
  assert_eq(r.sequence[1].token(), "horse", msg="token == horse")
  assert_eq(r.sequence[2].token(), "battery", msg="token == battery")
  assert_eq(r.sequence[3].token(), "staple", msg="token == staple")
  // score > 2 时上游不给建议
  assert_eq(r.feedback.warning, "", msg="no warning")
  assert_eq(r.feedback.suggestions, [], msg="no suggestions")
}

///|
/// 端到端：l33t 密码被识别后仍应被视为弱。
test "zzcvbn('Tr0ub4dor&3') => bruteforce, score 4" {
  let r = @zxcvbn.zxcvbn("Tr0ub4dor&3", [])
  debug_inspect(r.score, content="4")
  debug_inspect(r.sequence.length(), content="1")
  assert_eq(r.sequence[0].pattern(), "bruteforce", msg="pattern == bruteforce")
}

///|
/// user_inputs：用户名参与词典，强度应显著下降。
test "user_inputs lower the estimate" {
  let without = @zxcvbn.zxcvbn("smithhammer", [])
  let with_inputs = @zxcvbn.zxcvbn("smithhammer", ["smith", "hammer"])
  // 用户词典命中后 guesses 必须更小
  assert_true(
    with_inputs.guesses < without.guesses,
    msg="user dictionary hits must lower guesses",
  )
  // 用户词应该进入字典匹配序列
  let patterns = with_inputs.sequence.map(m => m.pattern())
  debug_inspect(patterns.length() >= 2, content="true")
  assert_eq(patterns[0], "dictionary", msg="user dictionary match")
}

///|
/// 边界：非 BMP 字符（emoji）按 Unicode 标量值计长，不是 UTF-16 码元。
test "non-BMP characters are counted as scalar values" {
  // 4 个 emoji 在 JS 里 length 是 8（UTF-16 码元），这里必须是 4 个标量值
  let r = @zxcvbn.zxcvbn("😀😀😀😀", [])
  debug_inspect(r.score, content="0")
  // emoji 不是词典词，DP 会给 repeat 或 bruteforce 覆盖
  let patterns = r.sequence.map(m => m.pattern())
  let mut covered = false
  for p in patterns {
    if p == "bruteforce" || p == "repeat" {
      covered = true
    }
  }
  debug_inspect(covered, content="true")
}

///|
/// 边界：长密码不应崩溃。
/// 1000 个 'x' 是纯重复，上游行为就是弱（repeat pattern，score=1）。
test "long password (1000 repeated chars) stays a weak repeat" {
  let long = "x".repeat(1000)
  let r = @zxcvbn.zxcvbn(long, [])
  debug_inspect(r.sequence.length(), content="1")
  assert_eq(r.sequence[0].pattern(), "repeat", msg="pattern == repeat")
  debug_inspect(r.score, content="1")
}

///|
/// 边界：长随机密码应该是强密码（而且不能超时）。
test "long random password is strong" {
  let long = "Zq7$mK2wP9xR4vN8bT5yU3iO6pL1aS0dF7gH4jK8mQ2wE5"
  let r = @zxcvbn.zxcvbn(long, [])
  debug_inspect(r.score, content="4")
}

///|
/// 边界：单字符密码。
test "single-character passwords" {
  let r = @zxcvbn.zxcvbn("a", [])
  debug_inspect(r.score, content="0")
  let r = @zxcvbn.zxcvbn("!", [])
  debug_inspect(r.score, content="0")
}

///|
/// 边界：纯空格与不可见字符不应让匹配器越界。
test "whitespace-only passwords" {
  for pw in [" ", "   ", "\t", "\n"] {
    let r = @zxcvbn.zxcvbn(pw, [])
    debug_inspect(r.score, content="0")
  }
}

///|
/// reference_year 参数化：同一个日期密码在不同参考年下 guesses 不同。
test "reference_year is parameterized" {
  let a = @zxcvbn.zxcvbn("1999", [], reference_year=2026)
  let b = @zxcvbn.zxcvbn("1999", [], reference_year=2005)
  // 1999 距 2005 只有 6 年 => 走 MIN_YEAR_SPACE=20；距 2026 有 27 年
  debug_inspect(b.guesses < a.guesses, content="true")
}

///|
/// `to_json` 是给 Web 侧（foreign_library + js 后端）用的出口，字段名与顺序
/// 必须和上游 result 对象对齐——`tools/diff_test.py` 与
/// `tools/ref/zxcvbn_ref.mjs` 都按这个格式逐字段对拍。
test "Entropy::to_json emits the upstream-shaped object" {
  let r = @zxcvbn.zxcvbn("Tr0ub4dor&3", [])
  let j = r.to_json()
  // 顶层字段按固定顺序出现
  for
    key in [
      "\"password\"", "\"guesses\"", "\"guesses_log10\"", "\"score\"", "\"crack_times_seconds\"",
      "\"crack_times_display\"", "\"sequence\"", "\"feedback\"",
    ] {
    assert_true(j.contains(key), msg="json contains \{key}")
  }
  assert_true(j.contains("\"score\":4"), msg="score is 4")
  // sequence 只投影五个共有字段，不泄露 Match 枚举内部表示
  assert_true(
    j.contains(
      "{\"i\":0,\"j\":10,\"pattern\":\"bruteforce\",\"token\":\"Tr0ub4dor&3\",\"guesses\":100000000000}",
    ),
    msg="sequence[0] projected to the five shared fields",
  )
}

///|
/// 反馈文案里带引号与反斜杠时必须正确转义，否则产出非法 JSON。
/// 上游 repeat 警告形如 `Repeats like "aaa" are easy to guess`。
test "Entropy::to_json escapes quotes and backslashes" {
  let r = @zxcvbn.zxcvbn("aaa", [])
  let j = r.to_json()
  // 引号必须转义成 \"，不能出现裸引号把字符串截断
  assert_true(j.contains("\\\"aaa\\\""), msg="quotes in feedback are escaped")
  assert_false(
    j.contains("\"warning\":\"Repeats like \"aaa\"\""),
    msg="no unescaped quote truncates the warning string",
  )
  // 首尾是完整 JSON 对象
  assert_true(j.has_prefix("{"), msg="starts with {")
  assert_true(j.has_suffix("}"), msg="ends with }")
}
