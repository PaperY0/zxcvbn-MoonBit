// scoring.mbt 的白盒测试：上游 test/test-scoring.coffee 官方向量的转写。

///|

/// 测试辅助：浮点数绝对值（`@math` 里没有 abs，那是 `@double` 的职责；

///|
/// 测试不想为此多引一个包）。
fn abs_d(v : Double) -> Double {
  if v < 0.0 {
    -v
  } else {
    v
  }
}

///|

///|
/// 测试辅助：浮点数近似相等（上游用 `approx_equal` 截断到 1e-10 后比较）。
fn assert_close(a : Double, b : Double) -> Unit raise {
  let diff = if a > b { a - b } else { b - a }

  assert_true(diff < 1.0e-9, msg="expected \{a} close to \{b} (diff \{diff})")
}

///|

/// 测试辅助：构造一个只有 i/j/guesses 的匹配

///|
///（上游 `search` 测试块里的 `m(i, j, guesses)` 就是这么用的）。
fn probe_match(i : Int, j : Int, guesses : Double) -> Match {

  // 上游的 m(i, j, guesses) 没有 pattern 字段，因此不触发 bruteforce_update 里

  // “相邻两个 bruteforce 就跳过”的判断。这里用 Regex 变体承载：guesses 已预置，

  // estimate_guesses 直接返回缓存值，永远不会分派到 regex_guesses。

  Match::Regex({
    i,
    j,
    token: "",
    regex_name: "probe",
    guesses,
    guesses_log10: 0,
  })
}

///|

///|
/// 上游 `test 'nCk'`。
test "official: nCk" {
  let rows = [
    (0, 0, 1.0),
    (1, 0, 1.0),
    (5, 0, 1.0),
    (0, 1, 0.0),
    (0, 5, 0.0),
    (2, 1, 2.0),
    (4, 2, 6.0),
    (33, 7, 4272048.0),
  ]

  for row in rows {
    let (n, k, expected) = row

    assert_eq(nCk(n, k), expected, msg="nCk(\{n}, \{k}) == \{expected}")
  }

  // mirror identity

  assert_eq(nCk(49, 12), nCk(49, 37), msg="mirror identity")

  // pascal's triangle identity

  assert_eq(
    nCk(49, 12),
    nCk(48, 11) + nCk(48, 12),
    msg="pascal's triangle identity",
  )
}

///|

///|
/// 上游 `test 'log'`。
test "official: log2/log10" {
  let rows2 = [(1.0, 0.0), (2.0, 1.0), (4.0, 2.0), (32.0, 5.0)]

  for row in rows2 {
    let (n, expected) = row

    assert_eq(log2(n), expected, msg="log2(\{n}) == \{expected}")
  }

  let rows10 = [(1.0, 0.0), (10.0, 1.0), (100.0, 2.0)]

  for row in rows10 {
    let (n, expected) = row

    assert_eq(log10(n), expected, msg="log10(\{n}) == \{expected}")
  }

  let n = 17.0

  let p = 4.0

  assert_close(log10(n * p), log10(n) + log10(p))

  assert_close(log10(n / p), log10(n) - log10(p))

  assert_close(log10(2.718281828459045), 1.0 / 2.302585092994046)

  assert_close(log10(@math.pow(n, p)), p * log10(n))

  assert_close(log10(n), @math.ln(n) / @math.ln(10.0))
}

///|

///|
/// 上游 `test 'search'`：最优序列 DP。
test "official: search (most_guessable_match_sequence)" {
  let password = "0123456789"

  // 上游在测试里把加性惩罚关掉

  let no_additive = true

  let run = (matches : Array[Match]) => {
    most_guessable_match_sequence(
      password,
      matches,
      2026,
      exclude_additive=no_additive,
    )
  }

  // returns one bruteforce match given an empty match sequence

  let result = run([])

  assert_eq(result.sequence.length(), 1, msg="length == 1")

  assert_eq(result.sequence[0].pattern(), "bruteforce", msg="bruteforce")

  assert_eq(result.sequence[0].token(), password, msg="token == password")

  assert_eq(result.sequence[0].start_index(), 0, msg="i == 0")

  assert_eq(result.sequence[0].end_index(), 9, msg="j == 9")

  // returns match + bruteforce when match covers a prefix

  let m0 = probe_match(0, 5, 1)

  let result = run([m0])

  assert_eq(result.sequence.length(), 2, msg="prefix: length == 2")

  assert_eq(result.sequence[0].start_index(), 0, msg="first match i")

  assert_eq(result.sequence[0].end_index(), 5, msg="first match j")

  assert_eq(
    result.sequence[1].pattern(),
    "bruteforce",
    msg="second is bruteforce",
  )

  assert_eq(result.sequence[1].start_index(), 6, msg="second covers [6, ..]")

  assert_eq(result.sequence[1].end_index(), 9, msg="... 9]")

  // returns bruteforce + match when match covers a suffix

  let m1 = probe_match(3, 9, 1)

  let result = run([m1])

  assert_eq(result.sequence.length(), 2, msg="suffix: length == 2")

  assert_eq(
    result.sequence[0].pattern(),
    "bruteforce",
    msg="first is bruteforce",
  )

  assert_eq(result.sequence[0].start_index(), 0, msg="first covers [0")

  assert_eq(result.sequence[0].end_index(), 2, msg=".. 2]")

  assert_eq(result.sequence[1].start_index(), 3, msg="second i")

  assert_eq(result.sequence[1].end_index(), 9, msg="second j")

  // returns bruteforce + match + bruteforce when match covers an infix

  let m1 = probe_match(1, 8, 1)

  let result = run([m1])

  assert_eq(result.sequence.length(), 3, msg="infix: length == 3")

  assert_eq(result.sequence[1].start_index(), 1, msg="middle i")

  assert_eq(result.sequence[1].end_index(), 8, msg="middle j")

  assert_eq(result.sequence[0].pattern(), "bruteforce", msg="first bruteforce")

  assert_eq(result.sequence[2].pattern(), "bruteforce", msg="third bruteforce")

  assert_eq(result.sequence[0].start_index(), 0, msg="first covers [0")

  assert_eq(result.sequence[0].end_index(), 0, msg=".. 0]")

  assert_eq(result.sequence[2].start_index(), 9, msg="third covers [9")

  assert_eq(result.sequence[2].end_index(), 9, msg=".. 9]")

  // chooses lower-guesses match given two matches of the same span

  let m0 = probe_match(0, 9, 1)

  let m1 = probe_match(0, 9, 2)

  let matches = [m0, m1]

  let result = run(matches)

  assert_eq(result.sequence.length(), 1, msg="same span: length == 1")

  assert_eq(result.sequence[0].guesses(), 1.0, msg="keeps the 1-guess match")

  // make sure ordering doesn't matter

  m0.set_guesses(3.0)

  let result = run(matches)

  assert_eq(result.sequence.length(), 1, msg="reordered: length == 1")

  assert_eq(result.sequence[0].guesses(), 2.0, msg="keeps the 2-guess match")

  // when m0 covers m1 and m2, choose [m0] when m0 < m1 * m2 * fact(2)

  let m0 = probe_match(0, 9, 3)

  let m1 = probe_match(0, 3, 2)

  let m2 = probe_match(4, 9, 1)

  let matches = [m0, m1, m2]

  let result = run(matches)

  assert_eq(result.guesses, 3.0, msg="total guesses == 3")

  assert_eq(result.sequence.length(), 1, msg="sequence is [m0]")

  // when m0 covers m1 and m2, choose [m1, m2] when m0 > m1 * m2 * fact(2)

  m0.set_guesses(5.0)

  let result = run(matches)

  assert_eq(result.guesses, 4.0, msg="total guesses == 4")

  assert_eq(result.sequence.length(), 2, msg="sequence is [m1, m2]")

  assert_eq(result.sequence[0].start_index(), 0, msg="m1 i")

  assert_eq(result.sequence[1].start_index(), 4, msg="m2 i")
}

///|

///|
/// 上游 `test 'repeat guesses'`。
test "official: repeat guesses" {
  let rows = [
    ("aa", "a", 2.0),
    ("999", "9", 3.0),
    ("$$$$", "$", 4.0),
    ("abab", "ab", 2.0),
    ("batterystaplebatterystaplebatterystaple", "batterystaple", 3.0),
  ]

  for row in rows {
    let (token, base_token, repeat_count) = row

    let matcher = Omnimatcher::new(Map([]), 2026)

    let base_analysis = most_guessable_match_sequence(
      base_token,
      matcher.run(base_token),
      2026,
    )

    let m = Match::Repeat({
      i: 0,
      j: token.to_array().length() - 1,
      token,
      base_token,
      base_guesses: base_analysis.guesses,
      base_matches: base_analysis.sequence,
      repeat_count: repeat_count.to_int(),
      guesses: 0,
      guesses_log10: 0,
    })

    let guesses = most_guessable_match_sequence(token, [m], 2026).sequence[0].guesses()

    assert_eq(
      guesses,
      base_analysis.guesses * repeat_count,
      msg="the repeat pattern '\{token}' has guesses of \{base_analysis.guesses * repeat_count}",
    )
  }
}

///|

///|
/// 上游 `test 'sequence guesses'`。
test "official: sequence guesses" {
  let rows = [
    ("ab", true, 4.0 * 2.0),
    ("XYZ", true, 26.0 * 3.0),
    ("4567", true, 10.0 * 4.0),
    ("7654", false, 10.0 * 4.0 * 2.0),
    ("ZYX", false, 4.0 * 3.0 * 2.0),
  ]

  for row in rows {
    let (token, ascending, expected) = row

    let m = Match::Sequence({
      i: 0,
      j: token.to_array().length() - 1,
      token,
      sequence_name: "lower",
      sequence_space: 26,
      ascending,
      guesses: 0,
      guesses_log10: 0,
    })

    let guesses = most_guessable_match_sequence(token, [m], 2026).sequence[0].guesses()

    assert_eq(
      guesses,
      expected,
      msg="the sequence pattern '\{token}' has guesses of \{expected}",
    )
  }
}

///|

/// 上游 `test 'regex guesses'`（本项目 REGEXEN 只有 recent_year，

///|
/// 因此只转写该分支——上游另两个 char_class_bases 分支不可达）。
test "official: regex guesses (recent_year)" {

  // 本项目把 reference_year 参数化；这里用 2017（上游跑测试时的年份），

  // 以复现上游的精确期望值。

  let ref_year = 2017

  let distant = {
    i: 0,
    j: 3,
    token: "1972",
    regex_name: "recent_year",
    guesses: 0,
    guesses_log10: 0,
  }

  assert_eq(
    regex_guesses(distant, ref_year),
    abs_d(1972.0 - ref_year.to_double()),
    msg="guesses of |year - REFERENCE_YEAR| for distant year matches",
  )

  let near = {
    i: 0,
    j: 3,
    token: "2005",
    regex_name: "recent_year",
    guesses: 0,
    guesses_log10: 0,
  }

  assert_eq(
    regex_guesses(near, ref_year),
    20.0,
    msg="guesses of MIN_YEAR_SPACE for a year close to REFERENCE_YEAR",
  )
}

///|

///|
/// 上游 `test 'date guesses'`。
test "official: date guesses" {
  let ref_year = 2017

  let no_sep = {
    i: 0,
    j: 3,
    token: "1123",
    separator: "",
    year: 1923,
    month: 1,
    day: 1,
    guesses: 0,
    guesses_log10: 0,
  }

  assert_eq(
    date_guesses(no_sep, ref_year),
    365.0 * abs_d(1923.0 - ref_year.to_double()),
    msg="guesses for 1123 is 365 * distance_from_ref_year",
  )

  let with_sep = {
    i: 0,
    j: 7,
    token: "1/1/2010",
    separator: "/",
    year: 2010,
    month: 1,
    day: 1,
    guesses: 0,
    guesses_log10: 0,
  }

  let msg = "recent years assume MIN_YEAR_SPACE. extra guesses are added for separators."

  assert_eq(date_guesses(with_sep, ref_year), 365.0 * 20.0 * 4.0, msg~)
}

///|

///|
/// 上游 `test 'spatial guesses'`。
test "official: spatial guesses" {
  let s = keyboard_starting_positions.to_double()

  let d = keyboard_average_degree

  let base_guesses = (token : String, turns : Int, shifts : Int) => {
    let m = Match::Spatial({
      i: 0,
      j: token.to_array().length() - 1,
      token,
      graph: "qwerty",
      turns,
      shifted_count: shifts,
      guesses: 0,
      guesses_log10: 0,
    })

    most_guessable_match_sequence(token, [m], 2026).sequence[0].guesses()
  }

  // with no turns or shifts, guesses is starts * degree * (len-1)

  let expected_base = s * d * 5.0

  assert_eq(base_guesses("zxcvbn", 1, 0), expected_base, msg="no turns/shifts")

  // guesses is added for shifted keys, similar to capitals in dictionary matching

  assert_eq(
    base_guesses("ZxCvbn", 1, 2),
    expected_base * (nCk(6, 2) + nCk(6, 1)),
    msg="shifted keys",
  )

  // when everything is shifted, guesses are doubled

  assert_eq(
    base_guesses("ZXCVBN", 1, 6),
    expected_base * 2.0,
    msg="all shifted",
  )

  // spatial guesses accounts for turn positions, directions and starting keys

  let token = "zxcft6yh"

  let l = token.to_array().length().to_double()

  let mut expected = 0.0

  let mut i = 2.0

  while i <= l {
    let mut j = 1.0

    while j <= (if 3.0 < i - 1.0 { 3.0 } else { i - 1.0 }) {
      expected = expected +
        nCk((i - 1.0).to_int(), (j - 1.0).to_int()) * s * @math.pow(d, j)

      j += 1.0
    }

    i += 1.0
  }

  assert_eq(base_guesses(token, 3, 0), expected, msg="turn positions")
}

///|

///|
/// 上游 `test 'dictionary_guesses'`。
test "official: dictionary guesses" {
  let guesses = (
    token : String,
    rank : Int,
    reversed : Bool,
    l33t : Bool,
    sub : Array[(Char, Char)],
  ) => {
    let m : DictionaryMatch = {
      i: 0,
      j: token.to_array().length() - 1,
      token,
      matched_word: token,
      rank,
      dictionary_name: Passwords,
      reversed,
      l33t,
      sub,
      guesses: 0,
      guesses_log10: 0,
    }

    dictionary_guesses(m)
  }

  // base guesses == the rank

  assert_eq(guesses("aaaaa", 32, false, false, []), 32.0, msg="rank == 32")

  // extra guesses are added for capitalization

  assert_eq(
    guesses("AAAaaa", 32, false, false, []),
    32.0 * (nCk(6, 1) + nCk(6, 2) + nCk(6, 3)),
    msg="capitalization",
  )

  // guesses are doubled when word is reversed

  assert_eq(guesses("aaa", 32, true, false, []), 64.0, msg="reversed doubles")

  // extra guesses are added for common l33t substitutions

  assert_eq(
    guesses("aaa@@@", 32, false, true, [('@', 'a')]),
    32.0 * (nCk(6, 1) + nCk(6, 2) + nCk(6, 3)),
    msg="l33t substitutions",
  )

  // extra guesses are added for both

  assert_eq(
    guesses("AaA@@@", 32, false, true, [('@', 'a')]),

    // AaA@@@: U=2, L=1 (只有 1 个小写 a)
    // => uppercase 乘数是 nCk(3,1)=3；l33t 乘数是 41。
    32.0 * nCk(3, 1) * (nCk(6, 1) + nCk(6, 2) + nCk(6, 3)),
    msg="both capitalization and l33t",
  )
}

///|

///|
/// 上游 `test 'uppercase variants'`。
test "official: uppercase variants" {
  let rows = [
    ("", 1.0),
    ("a", 1.0),
    ("A", 2.0),
    ("abcdef", 1.0),
    ("Abcdef", 2.0),
    ("abcdeF", 2.0),
    ("ABCDEF", 2.0),
    ("aBcdef", nCk(6, 1)),
    ("aBcDef", nCk(6, 1) + nCk(6, 2)),
    ("ABCDEf", nCk(6, 1)),
    ("aBCDEf", nCk(6, 1) + nCk(6, 2)),
    ("ABCdef", nCk(6, 1) + nCk(6, 2) + nCk(6, 3)),
  ]

  for row in rows {
    let (word, expected) = row

    assert_eq(
      uppercase_variations(word),
      expected,
      msg="guess multiplier of '\{word}' is \{expected}",
    )
  }
}

///|
/// 测试帮助：构造一个 DictionaryMatch（l33t 含义由 sub 是否为空推导）。
fn mk_dict(word : String, sub : Array[(Char, Char)]) -> DictionaryMatch {
  {
    i: 0,
    j: word.to_array().length() - 1,
    token: word,
    matched_word: word,
    rank: 1,
    dictionary_name: Passwords,
    reversed: false,
    l33t: sub.length() > 0,
    sub,
    guesses: 0,
    guesses_log10: 0,
  }
}

///|

///|
/// 上游 `test 'l33t variants'`。
test "official: l33t variants" {
  assert_eq(l33t_variations(mk_dict("", [])), 1.0, msg="1 variant for empty")

  assert_eq(
    l33t_variations(mk_dict("a", [])),
    1.0,
    msg="1 variant for non-l33t",
  )

  assert_eq(
    l33t_variations(mk_dict("4", [('4', 'a')])),
    2.0,
    msg="fully subbed",
  )

  assert_eq(l33t_variations(mk_dict("4pple", [('4', 'a')])), 2.0, msg="4pple")

  assert_eq(l33t_variations(mk_dict("abcet", [])), 1.0, msg="no subs")

  assert_eq(l33t_variations(mk_dict("4bcet", [('4', 'a')])), 2.0, msg="4bcet")

  assert_eq(l33t_variations(mk_dict("a8cet", [('8', 'b')])), 2.0, msg="a8cet")

  assert_eq(l33t_variations(mk_dict("abce+", [('+', 't')])), 2.0, msg="abce+")

  assert_eq(
    l33t_variations(mk_dict("48cet", [('4', 'a'), ('8', 'b')])),
    4.0,
    msg="48cet",
  )

  assert_eq(
    l33t_variations(mk_dict("a4a4aa", [('4', 'a')])),
    nCk(6, 2) + nCk(6, 1),
    msg="a4a4aa",
  )

  assert_eq(
    l33t_variations(mk_dict("4a4a44", [('4', 'a')])),
    nCk(6, 2) + nCk(6, 1),
    msg="4a4a44",
  )

  assert_eq(
    l33t_variations(mk_dict("a44att+", [('4', 'a'), ('+', 't')])),
    (nCk(4, 2) + nCk(4, 1)) * nCk(3, 1),
    msg="a44att+",
  )

  // capitalization doesn't affect extra l33t guesses calc

  let m : DictionaryMatch = {
    i: 0,
    j: 5,
    token: "Aa44aA",
    matched_word: "aa44aa",
    rank: 1,
    dictionary_name: Passwords,
    reversed: false,
    l33t: true,
    sub: [('4', 'a')],
    guesses: 0,
    guesses_log10: 0,
  }

  assert_eq(
    l33t_variations(m),
    nCk(6, 2) + nCk(6, 1),
    msg="capitalization doesn't affect l33t guesses",
  )
}

///|

///|
/// 上游 `test 'calc_guesses'`。
test "official: calc_guesses (cached + dispatch)" {
  // estimate_guesses returns cached guesses when available
  let cached = probe_match(0, 3, 1)
  let guesses = most_guessable_match_sequence("1977", [cached], 2017).sequence[0].guesses()
  assert_eq(guesses, 1.0, msg="cached guesses == 1")

  // estimate_guesses delegates based on pattern
  let date_match = {
    i: 0,
    j: 3,
    token: "1977",
    separator: "",
    year: 1977,
    month: 7,
    day: 14,
    guesses: 0,
    guesses_log10: 0,
  }
  let expected = date_guesses(date_match, 2017)
  assert_eq(
    expected,
    40.0 * 365.0,
    msg="|1977 - 2017| = 40 > MIN_YEAR_SPACE = 20",
  )
  // 直接调 estimate_guesses 验证分洼（走 DP 的话它可能更值盘选 bruteforce）
  assert_eq(
    estimate_guesses(Match::Date(date_match), 4, 2017),
    expected,
    msg="estimate_guesses delegates to date_guesses",
  )
}
