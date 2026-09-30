// feedback.mbt 的黑盒测试：按最长匹配的模式分派 warning/suggestions。
//
// 断言一律用 assert_eq，不依赖 Debug 输出的格式。

///|
/// score > 2 时上游不给任何建议。
test "no feedback for strong passwords" {
  let r = @zxcvbn.zxcvbn("correcthorsebatterystaple", [])
  assert_eq(r.score, 4, msg="score == 4")
  assert_eq(r.feedback.warning, "", msg="no warning")
  assert_eq(r.feedback.suggestions, [], msg="no suggestions")
}

///|
/// dictionary：top-10 常见密码的 warning。
test "feedback for a top-10 common password" {
  let r = @zxcvbn.zxcvbn("password", [])
  assert_eq(
    r.feedback.warning,
    "This is a top-10 common password",
    msg="top-10 warning",
  )
  // 全小写 => 没有 "Capitalization doesn't help very much"
  assert_eq(
    r.feedback.suggestions,
    ["Add another word or two. Uncommon words are better."],
    msg="only the generic suggestion",
  )
}

///|
/// dictionary：首字母大写会追加一条 capitalization 建议。
test "feedback adds a capitalization suggestion for Password" {
  let r = @zxcvbn.zxcvbn("Password", [])
  assert_eq(
    r.feedback.warning,
    "This is a top-10 common password",
    msg="top-10 warning",
  )
  let mut found = false
  for s in r.feedback.suggestions {
    if s == "Capitalization doesn't help very much" {
      found = true
    }
  }
  assert_eq(found, true, msg="capitalization suggestion present")
}

///|
/// dictionary：l33t 替换会追加一条 substitution 建议。
test "feedback adds an l33t suggestion for p4ssword" {
  let r = @zxcvbn.zxcvbn("p4ssword", [])
  let mut found = false
  for s in r.feedback.suggestions {
    if s ==
      "Predictable substitutions like '@' instead of 'a' don't help very much" {
      found = true
    }
  }
  assert_eq(found, true, msg="l33t substitution suggestion present")
}

///|
/// dictionary：反转词会追加一条 reversed 建议。
test "feedback adds a reversed suggestion for drowssap" {
  let r = @zxcvbn.zxcvbn("drowssap", [])
  let mut found = false
  for s in r.feedback.suggestions {
    if s == "Reversed words aren't much harder to guess" {
      found = true
    }
  }
  assert_eq(found, true, msg="reversed suggestion present")
}

///|
/// spatial：直行键盘。（用 `vfr4bgt5` 而非 `zxcvbn`：
/// 后者本身是 top-100 常见密码，反馈会被字典分支抢走。）
test "feedback for a straight keyboard row" {
  let r = @zxcvbn.zxcvbn("vfr4bgt5", [])
  assert_eq(
    r.feedback.warning,
    "Straight rows of keys are easy to guess",
    msg="straight rows warning",
  )
}

///|
/// spatial：多转向的短键盘模式。
test "feedback for a short keyboard pattern" {
  let r = @zxcvbn.zxcvbn("rz!6tfGHJ%z", [])
  // 这里最长匹配未必是 spatial（DP 可能选 bruteforce），因此只验证
  // 若 warning 非空，则它来自 spatial 分支的两种文案之一
  let w = r.feedback.warning
  assert_true(
    w == "" ||
    w == "Straight rows of keys are easy to guess" ||
    w == "Short keyboard patterns are easy to guess",
    msg="unexpected warning: \{w}",
  )
}

///|
/// repeat：单字符重复。
test "feedback for a single-character repeat" {
  let r = @zxcvbn.zxcvbn("aaaaa", [])
  assert_eq(
    r.feedback.warning,
    "Repeats like \"aaa\" are easy to guess",
    msg="single-char repeat warning",
  )
}

///|
/// repeat：多字符重复。
test "feedback for a multi-character repeat" {
  let r = @zxcvbn.zxcvbn("abcabcabcabc", [])
  assert_eq(
    r.feedback.warning,
    "Repeats like \"abcabcabc\" are only slightly harder to guess than \"abc\"",
    msg="multi-char repeat warning",
  )
}

///|
/// sequence：字母序列。
test "feedback for a sequence" {
  let r = @zxcvbn.zxcvbn("abcde", [])
  assert_eq(
    r.feedback.warning,
    "Sequences like abc or 6543 are easy to guess",
    msg="sequence warning",
  )
}

///|
/// date：日期。
test "feedback for a date" {
  let r = @zxcvbn.zxcvbn("11/20/1991", [])
  assert_eq(
    r.feedback.warning,
    "Dates are often easy to guess",
    msg="date warning",
  )
}

///|
/// regex：近年份。
test "feedback for a recent year" {
  let r = @zxcvbn.zxcvbn("2017", [])
  assert_eq(
    r.feedback.warning,
    "Recent years are easy to guess",
    msg="recent year warning",
  )
}

///|
/// 空密码走 default_feedback。
test "default feedback for an empty password" {
  let r = @zxcvbn.zxcvbn("", [])
  assert_eq(r.feedback.warning, "", msg="no warning")
  assert_eq(
    r.feedback.suggestions,
    [
      "Use a few words, avoid common phrases", "No need for symbols, digits, or uppercase letters",
    ],
    msg="default feedback suggestions",
  )
}
