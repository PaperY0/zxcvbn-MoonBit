// matching.mbt 的白盒测试：上游 test/test-matching.coffee 官方向量的转写。
//
// 上游用 tape 的 `t.equal` / `t.deepEqual` 逐个断言；这里转成 `assert_eq` /
// `debug_inspect`，并保留上游注释里的语义说明。

///|
/// 上游 `check_matches` 的最小可用版：按顺序断言 (pattern, i, j)。
fn assert_match_ids(
  matches : Array[Match],
  expected : Array[(String, Int, Int)],
  ctx : String,
) -> Unit raise {
  assert_eq(
    matches.length(),
    expected.length(),
    msg="\{ctx}: expected \{expected.length()} matches, got \{matches.length()}",
  )
  let mut k = 0
  while k < expected.length() {
    let (pattern, i, j) = expected[k]
    assert_eq(
      matches[k].pattern(),
      pattern,
      msg="\{ctx}: matches[\{k}].pattern == \{pattern}",
    )
    assert_eq(
      matches[k].start_index(),
      i,
      msg="\{ctx}: matches[\{k}].i == \{i}",
    )
    assert_eq(matches[k].end_index(), j, msg="\{ctx}: matches[\{k}].j == \{j}")
    k += 1
  }
}

///|
/// 上游 `genpws`：把模式嵌进所有 prefix/suffix 组合（含空前缀/空后缀），
/// 返回 `(variant, i, j)`，i/j 为模式在变体里的闭区间下标。
fn genpws(
  pattern : String,
  prefixes : Array[String],
  suffixes : Array[String],
) -> Array[(String, Int, Int)] {
  let result : Array[(String, Int, Int)] = []
  let plen = pattern.to_array().length()
  for prefix in prefixes {
    for suffix in suffixes {
      let start = prefix.to_array().length()
      result.push((prefix + pattern + suffix, start, start + plen - 1))
    }
  }
  result
}

// ---------------------------------------------------------------------------
// 官方向量：matching utils
// ---------------------------------------------------------------------------

///|
/// 上游 `test 'matching utils'`。
test "official: matching utils (empty/extend/translate/mod/sorted)" {
  // extend
  let lst : Array[Int] = []
  extend_matches(lst, [])
  assert_eq(lst, [])
  extend_matches(lst, [1])
  assert_eq(lst, [1])
  extend_matches(lst, [2, 3])
  assert_eq(lst, [1, 2, 3])
  let lst1 : Array[Int] = [1]
  let lst2 : Array[Int] = [2]
  extend_matches(lst1, lst2)
  assert_eq(lst2, [2])

  // translate
  let chr_map : Map[Char, Char] = Map([('a', 'A'), ('b', 'B')])
  assert_eq(translate_str("a", chr_map), "A")
  assert_eq(translate_str("c", chr_map), "c")
  assert_eq(translate_str("ab", chr_map), "AB")
  assert_eq(translate_str("abc", chr_map), "ABc")
  assert_eq(translate_str("aa", chr_map), "AA")
  assert_eq(translate_str("abab", chr_map), "ABAB")
  assert_eq(translate_str("", chr_map), "")

  // mod
  assert_eq(mod_impl(0, 1), 0)
  assert_eq(mod_impl(1, 1), 0)
  assert_eq(mod_impl(-1, 1), 0)
  assert_eq(mod_impl(5, 5), 0)
  assert_eq(mod_impl(3, 5), 3)
  assert_eq(mod_impl(-1, 5), 4)
  assert_eq(mod_impl(-5, 5), 0)
  assert_eq(mod_impl(6, 5), 1)

  // sorted: i 主序、j 次序
  let ms : Array[Match] = [
    Match::Bruteforce({ i: 5, j: 5, token: "", guesses: 0, guesses_log10: 0, }),
    Match::Bruteforce({ i: 6, j: 7, token: "", guesses: 0, guesses_log10: 0, }),
    Match::Bruteforce({ i: 2, j: 5, token: "", guesses: 0, guesses_log10: 0, }),
    Match::Bruteforce({ i: 0, j: 0, token: "", guesses: 0, guesses_log10: 0, }),
    Match::Bruteforce({ i: 2, j: 3, token: "", guesses: 0, guesses_log10: 0, }),
    Match::Bruteforce({ i: 0, j: 3, token: "", guesses: 0, guesses_log10: 0, }),
  ]
  let sorted = sort_matches(ms)
  let ids = sorted.map(m => (m.start_index(), m.end_index()))
  assert_eq(
    ids,
    [(0, 0), (0, 3), (2, 3), (2, 5), (5, 5), (6, 7)],
    msg="matches are sorted on i index primary, j secondary",
  )
}

// ---------------------------------------------------------------------------
// 官方向量：dictionary matching
// ---------------------------------------------------------------------------

///|
/// 上游 `test 'dictionary matching'` 的测试词典。
///
/// 上游用任意名字的词典（d1/d2）；本项目的 Dictionary 是固定枚举，
/// 用 Passwords / English 两个值分别对应 d1 / d2。
fn official_dicts() -> Array[(Dictionary, Map[String, Int])] {
  [
    (
      Passwords,
      Map([
        ("motherboard", 1),
        ("mother", 2),
        ("board", 3),
        ("abcd", 4),
        ("cdef", 5),
      ]),
    ),
    (English, Map([("z", 1), ("8", 2), ("99", 3), ("$", 4), ("asdf1234&*", 5)])),
  ]
}

///|
/// 测试辅助：测试词典集里最长的词长。
fn official_max_len() -> Int {
  let mut m = 1
  for entry in official_dicts() {
    let (_, ranked) = entry
    for word in ranked.keys() {
      let len = word.to_array().length()
      if len > m {
        m = len
      }
    }
  }
  m
}

///|
/// 测试辅助：把字符串经 translate 后再转回字符串（方便断言）。
fn translate_str(s : String, chr_map : Map[Char, Char]) -> String {
  String::from_array(translate(s.to_array(), chr_map))
}

///|
/// 测试辅助：Dictionary 转成上游的字符串名。
fn dict_name(d : Dictionary) -> String {
  match d {
    Passwords => "Passwords"
    English => "English"
    FemaleNames => "FemaleNames"
    MaleNames => "MaleNames"
    Surnames => "Surnames"
    UsTvAndFilm => "UsTvAndFilm"
    UserInputs => "UserInputs"
  }
}

///|
test "official: dictionary matching" {
  let dicts = official_dicts()
  let max_len = official_max_len()
  // matches words that contain other words
  let m = dictionary_match("motherboard".to_array(), dicts, max_len)
  assert_match_ids(
    m,
    [("dictionary", 0, 5), ("dictionary", 0, 10), ("dictionary", 6, 10)],
    "motherboard",
  )
  match m[0] {
    Dictionary(d) => {
      assert_eq(d.matched_word, "mother", msg="matched_word == mother")
      assert_eq(d.rank, 2, msg="rank == 2")
      assert_eq(
        dict_name(d.dictionary_name),
        "Passwords",
        msg="dictionary_name",
      )
    }
    _ => fail("expected dictionary match")
  }

  // matches multiple words when they overlap
  let m = dictionary_match("abcdef".to_array(), dicts, max_len)
  assert_match_ids(m, [("dictionary", 0, 3), ("dictionary", 2, 5)], "abcdef")

  // ignores uppercasing
  let m = dictionary_match("BoaRdZ".to_array(), dicts, max_len)
  assert_match_ids(m, [("dictionary", 0, 4), ("dictionary", 5, 5)], "BoaRdZ")
  match m[0] {
    Dictionary(d) =>
      assert_eq(d.matched_word, "board", msg="ignores uppercasing")
    _ => fail("expected dictionary match")
  }
  match m[1] {
    Dictionary(d) => {
      assert_eq(d.matched_word, "z", msg="z")
      assert_eq(dict_name(d.dictionary_name), "English", msg="dictionary_name")
    }
    _ => fail("expected dictionary match")
  }

  // identifies words surrounded by non-words
  let word = "asdf1234&*"
  for variant in genpws(word, ["", "q", "%%"], ["", "%", "qq"]) {
    let (password, i, j) = variant
    let m = dictionary_match(password.to_array(), dicts, max_len)
    assert_match_ids(m, [("dictionary", i, j)], "surrounded by non-words")
    match m[0] {
      Dictionary(d) => {
        assert_eq(d.matched_word, word, msg="matched_word")
        assert_eq(d.rank, 5, msg="rank == 5")
      }
      _ => fail("expected dictionary match")
    }
  }

  // matches against all words in provided dictionaries
  for entry in official_dicts() {
    let (dict_name_, ranked) = entry
    for word in ranked.keys() {
      if word == "motherboard" {
        continue // skip words that contain others
      }
      let m = dictionary_match(word.to_array(), dicts, max_len)
      assert_match_ids(
        m,
        [("dictionary", 0, word.to_array().length() - 1)],
        word,
      )
      match m[0] {
        Dictionary(d) => {
          assert_eq(d.matched_word, word, msg="matched_word == word")
          assert_eq(d.rank, ranked[word], msg="rank matches the dict entry")
          assert_eq(d.dictionary_name, dict_name_, msg="dictionary_name")
        }
        _ => fail("expected dictionary match")
      }
    }
  }

  // default dictionaries: 'wow' 在 us_tv_and_film 里 rank 322
  let builtin = builtin_dictionaries.map(pair => (pair.0, pair.1.force()))
  let cap = max_dictionary_word_length.force()
  let m = dictionary_match("wow".to_array(), builtin, cap)
  assert_match_ids(m, [("dictionary", 0, 2)], "default dictionaries")
  match m[0] {
    Dictionary(d) => {
      assert_eq(d.rank, 322, msg="wow rank == 322")
      assert_eq(
        dict_name(d.dictionary_name),
        "UsTvAndFilm",
        msg="us_tv_and_film",
      )
    }
    _ => fail("expected dictionary match")
  }

  // matches with provided user input dictionary
  let user_dicts : Array[(Dictionary, Map[String, Int])] = [
    (UserInputs, build_ranked_dict(["foo", "bar"])),
  ]
  let m = dictionary_match("foobar".to_array(), user_dicts, 3)
  assert_match_ids(m, [("dictionary", 0, 2), ("dictionary", 3, 5)], "foobar")
  match m[0] {
    Dictionary(d) => {
      assert_eq(d.matched_word, "foo", msg="matched_word == foo")
      assert_eq(d.rank, 1, msg="rank == 1")
    }
    _ => fail("expected dictionary match")
  }
  match m[1] {
    Dictionary(d) => assert_eq(d.rank, 2, msg="rank == 2")
    _ => fail("expected dictionary match")
  }
}

// ---------------------------------------------------------------------------
// 官方向量：reverse dictionary matching
// ---------------------------------------------------------------------------

///|
test "official: reverse dictionary matching" {
  let dicts : Array[(Dictionary, Map[String, Int])] = [
    (Passwords, Map([("123", 1), ("321", 2), ("456", 3), ("654", 4)])),
  ]
  let m = reverse_dictionary_match("0123456789".to_array(), dicts, 3)
  assert_match_ids(
    m,
    [("dictionary", 1, 3), ("dictionary", 4, 6)],
    "reverse: 0123456789",
  )
  match m[0] {
    Dictionary(d) => {
      assert_eq(d.matched_word, "321", msg="matched_word == 321")
      assert_eq(d.rank, 2, msg="rank == 2")
      assert_eq(d.reversed, true, msg="reversed")
      assert_eq(d.token, "123", msg="token == 123")
    }
    _ => fail("expected dictionary match")
  }
  match m[1] {
    Dictionary(d) => {
      assert_eq(d.matched_word, "654", msg="matched_word == 654")
      assert_eq(d.rank, 4, msg="rank == 4")
      assert_eq(d.reversed, true, msg="reversed")
    }
    _ => fail("expected dictionary match")
  }
}

// ---------------------------------------------------------------------------
// 官方向量：l33t matching
// ---------------------------------------------------------------------------

///|
/// 上游 `test 'l33t matching'` 用的小表（只含 4 个字母）。
fn official_l33t_table() -> Map[Char, Array[Char]] {
  Map([
    ('a', ['4', '@']),
    ('c', ['(', '{', '[', '<']),
    ('g', ['6', '9']),
    ('o', ['0']),
  ])
}

///|
/// 测试辅助：把 relevant_l33t_subtable 的结果按 subbed 字符排序后返回，
/// 便于与官方向量做确定性的 debug_inspect 断言。
fn l33t_subtable_of(
  pw : String,
  table : Map[Char, Array[Char]],
) -> Array[(Char, Array[Char])] {
  let sub = relevant_l33t_subtable(pw.to_array(), table)
  let pairs : Array[(Char, Array[Char])] = []
  for key in sub.keys() {
    pairs.push((key, sub[key]))
  }
  pairs.sort_by((a, b) => a.0.to_int() - b.0.to_int())
  pairs
}

///|
/// 测试辅助：把 enumerate_l33t_subs 的结果渲染成稳定的字符串列表
/// （Map 迭代顺序未定义，故按 subbed 字符排序后再拼接）。
fn l33t_subs_render(table : Map[Char, Array[Char]]) -> Array[String] {
  let out : Array[String] = []
  for sub in enumerate_l33t_subs(table) {
    let pairs = sub.to_array()
    pairs.sort_by((a, b) => a.0.to_int() - b.0.to_int())
    out.push(pairs.map(pair => "\{pair.0}->\{pair.1}").join(","))
  }
  out
}

///|
test "official: relevant_l33t_subtable" {
  let table = official_l33t_table()
  assert_eq(l33t_subtable_of("", table), [])
  assert_eq(l33t_subtable_of("abcdefgo123578!#$&*)]}>", table), [])
  assert_eq(l33t_subtable_of("a", table), [])
  debug_inspect(l33t_subtable_of("4", table), content="[('a', ['4'])]")
  debug_inspect(l33t_subtable_of("4@", table), content="[('a', ['4', '@'])]")
  debug_inspect(
    l33t_subtable_of("4({60", table),
    content="[('a', ['4']), ('c', ['(', '{']), ('g', ['6']), ('o', ['0'])]",
  )
}

///|
test "official: enumerate_l33t_subs" {
  debug_inspect(l33t_subs_render(Map([])), content="[\"\"]")
  debug_inspect(l33t_subs_render(Map([('a', ['@'])])), content="[\"@->a\"]")
  debug_inspect(
    l33t_subs_render(Map([('a', ['@', '4'])])),
    content="[\"@->a\", \"4->a\"]",
  )
  debug_inspect(
    l33t_subs_render(Map([('a', ['@', '4']), ('c', ['('])])),
    content="[\"(->c,@->a\", \"(->c,4->a\"]",
  )
}

///|
test "official: l33t matching" {
  let table = official_l33t_table()
  let dicts : Array[(Dictionary, Map[String, Int])] = [
    (
      Passwords,
      Map([("aac", 1), ("password", 3), ("paassword", 4), ("asdf0", 5)]),
    ),
    (English, Map([("cgo", 1)])),
  ]
  let max_len = 8
  // doesn't match '' and pure dictionary words
  assert_eq(l33t_match("".to_array(), dicts, table, max_len).length(), 0)
  assert_eq(
    l33t_match("password".to_array(), dicts, table, max_len).length(),
    0,
  )

  let m = l33t_match("p4ssword".to_array(), dicts, table, max_len)
  assert_match_ids(m, [("dictionary", 0, 7)], "p4ssword")
  match m[0] {
    Dictionary(d) => {
      assert_eq(d.matched_word, "password", msg="matched_word == password")
      assert_eq(d.rank, 3, msg="rank == 3")
      assert_eq(d.l33t, true, msg="l33t")
      assert_eq(d.sub, [('4', 'a')], msg="sub == {4 -> a}")
    }
    _ => fail("expected dictionary match")
  }

  let m = l33t_match("p@ssw0rd".to_array(), dicts, table, max_len)
  assert_match_ids(m, [("dictionary", 0, 7)], "p@ssw0rd")
  match m[0] {
    Dictionary(d) =>
      assert_eq(d.sub, [('0', 'o'), ('@', 'a')], msg="sub == {0 -> o, @ -> a}")
    _ => fail("expected dictionary match")
  }

  let m = l33t_match("aSdfO{G0asDfO".to_array(), dicts, table, max_len)
  assert_match_ids(m, [("dictionary", 5, 7)], "aSdfO{G0asDfO")
  match m[0] {
    Dictionary(d) => {
      assert_eq(d.matched_word, "cgo", msg="matched_word == cgo")
      assert_eq(d.sub, [('0', 'o'), ('{', 'c')], msg="sub == {0 -> o, { -> c}")
    }
    _ => fail("expected dictionary match")
  }

  // matches against overlapping l33t patterns
  let m = l33t_match("@a(go{G0".to_array(), dicts, table, max_len)
  assert_match_ids(
    m,
    [("dictionary", 0, 2), ("dictionary", 2, 4), ("dictionary", 5, 7)],
    "@a(go{G0",
  )
  match m[0] {
    Dictionary(d) => assert_eq(d.matched_word, "aac", msg="aac")
    _ => fail("expected dictionary match")
  }
  match m[1] {
    Dictionary(d) => assert_eq(d.matched_word, "cgo", msg="cgo")
    _ => fail("expected dictionary match")
  }
  match m[2] {
    Dictionary(d) => assert_eq(d.matched_word, "cgo", msg="cgo")
    _ => fail("expected dictionary match")
  }

  // doesn't match when multiple l33t substitutions are needed for the same letter
  assert_eq(
    l33t_match("p4@ssword".to_array(), dicts, table, max_len).length(),
    0,
  )
  // doesn't match single-character l33ted words
  assert_eq(l33t_match("4 1 @".to_array(), dicts, table, max_len).length(), 0)
  // known issue (上游注释保留): 不尝试替换的子集
  assert_eq(l33t_match("4sdf0".to_array(), dicts, table, max_len).length(), 0)
}

// ---------------------------------------------------------------------------
// 官方向量：spatial matching
// ---------------------------------------------------------------------------

///|
test "official: spatial matching" {
  let qwerty = get_graph("qwerty")
  for pw in ["", "/", "qw", "*/"] {
    assert_eq(spatial_match(pw.to_array(), [("qwerty", qwerty)]).length(), 0)
  }
  // matches against spatial patterns surrounded by non-spatial patterns
  let pattern = "6tfGHJ"
  let m = spatial_match("rz!\{pattern}%z".to_array(), [("qwerty", qwerty)])
  assert_match_ids(m, [("spatial", 3, 3 + 5)], "rz!6tfGHJ%z")
  match m[0] {
    Spatial(s) => {
      assert_eq(s.graph, "qwerty", msg="graph == qwerty")
      assert_eq(s.turns, 2, msg="turns == 2")
      assert_eq(s.shifted_count, 3, msg="shifted_count == 3")
    }
    _ => fail("expected spatial match")
  }

  let cases = [
    ("12345", "qwerty", 1, 0),
    ("@WSX", "qwerty", 1, 4),
    ("6tfGHJ", "qwerty", 2, 3),
    ("hGFd", "qwerty", 1, 2),
    ("/;p09876yhn", "qwerty", 3, 0),
    ("Xdr%", "qwerty", 1, 2),
    ("159-", "keypad", 1, 0),
    ("*84", "keypad", 1, 0),
    ("/8520", "keypad", 1, 0),
    ("369", "keypad", 1, 0),
    ("/963.", "mac_keypad", 1, 0),
    ("*-632.0214", "mac_keypad", 9, 0),
    ("aoEP%yIxkjq:", "dvorak", 4, 5),
    (";qoaOQ:Aoq;a", "dvorak", 11, 4),
  ]
  for row in cases {
    let (pattern, keyboard, turns, shifts) = row
    let graph = get_graph(keyboard)
    let m = spatial_match(pattern.to_array(), [(keyboard, graph)])
    assert_match_ids(
      m,
      [("spatial", 0, pattern.to_array().length() - 1)],
      "\{pattern} on \{keyboard}",
    )
    match m[0] {
      Spatial(s) => {
        assert_eq(s.graph, keyboard, msg="\{pattern}: graph == \{keyboard}")
        assert_eq(
          s.turns,
          turns,
          msg="\{pattern} (\{keyboard}): turns == \{turns}, got \{s.turns}",
        )
        assert_eq(
          s.shifted_count,
          shifts,
          msg="\{pattern} (\{keyboard}): shifted == \{shifts}, got \{s.shifted_count}",
        )
      }
      _ => fail("expected spatial match")
    }
  }
}

// ---------------------------------------------------------------------------
// 官方向量：sequence matching
// ---------------------------------------------------------------------------

///|
test "official: sequence matching" {
  for pw in ["", "a", "1"] {
    assert_eq(sequence_match(pw.to_array()).length(), 0)
  }
  // matches overlapping patterns
  let m = sequence_match("abcbabc".to_array())
  assert_match_ids(
    m,
    [("sequence", 0, 2), ("sequence", 2, 4), ("sequence", 4, 6)],
    "abcbabc",
  )
  let flags = m.map(mm => {
    match mm {
      Sequence(s) => s.ascending
      _ => fail("expected sequence match")
    }
  })
  assert_eq(flags, [true, false, true], msg="ascending flags")

  // matches embedded sequence patterns
  for variant in genpws("jihg", ["", "!", "22"], ["", "!", "22"]) {
    let (password, i, j) = variant
    let m = sequence_match(password.to_array())
    assert_match_ids(m, [("sequence", i, j)], "embedded \{password}")
    match m[0] {
      Sequence(s) => {
        assert_eq(s.sequence_name, "lower", msg="sequence_name == lower")
        assert_eq(s.ascending, false, msg="ascending == false")
      }
      _ => fail("expected sequence match")
    }
  }

  let cases = [
    ("ABC", "upper", true),
    ("CBA", "upper", false),
    ("PQR", "upper", true),
    ("RQP", "upper", false),
    ("XYZ", "upper", true),
    ("ZYX", "upper", false),
    ("abcd", "lower", true),
    ("dcba", "lower", false),
    ("jihg", "lower", false),
    ("wxyz", "lower", true),
    ("zxvt", "lower", false),
    ("0369", "digits", true),
    ("97531", "digits", false),
  ]
  for row in cases {
    let (pattern, name, is_ascending) = row
    let m = sequence_match(pattern.to_array())
    assert_match_ids(
      m,
      [("sequence", 0, pattern.to_array().length() - 1)],
      pattern,
    )
    match m[0] {
      Sequence(s) => {
        assert_eq(s.sequence_name, name, msg="\{pattern}: name == \{name}")
        assert_eq(
          s.sequence_space,
          if name == "digits" {
            10
          } else {
            26
          },
          msg="\{pattern}: sequence_space",
        )
        assert_eq(s.ascending, is_ascending, msg="\{pattern}: ascending")
      }
      _ => fail("expected sequence match")
    }
  }
}

// ---------------------------------------------------------------------------
// 官方向量：repeat matching
// ---------------------------------------------------------------------------

///|
fn run_repeat(pw : String) -> Array[Match] {
  repeat_match(
    pw.to_array(),
    official_dicts(),
    official_max_len(),
    official_l33t_table(),
    2026,
  )
}

///|
test "official: repeat matching" {
  for pw in ["", "#"] {
    assert_eq(run_repeat(pw).length(), 0)
  }
  // matches embedded repeat patterns
  for variant in genpws("&&&&&", ["", "@", "y4@"], ["", "u", "u%7"]) {
    let (password, i, j) = variant
    let m = run_repeat(password)
    assert_match_ids(m, [("repeat", i, j)], "embedded \{password}")
    match m[0] {
      Repeat(r) => assert_eq(r.base_token, "&", msg="base_token == &")
      _ => fail("expected repeat match")
    }
  }
  // matches repeats with base character
  for length in [3, 12] {
    for chr in ["a", "Z", "4", "&"] {
      let pattern = chr.repeat(length)
      let m = run_repeat(pattern)
      assert_match_ids(m, [("repeat", 0, length - 1)], pattern)
      match m[0] {
        Repeat(r) => assert_eq(r.base_token, chr, msg="base_token == \{chr}")
        _ => fail("expected repeat match")
      }
    }
  }
  // matches multiple adjacent repeats
  let m = run_repeat("BBB1111aaaaa@@@@@@")
  assert_match_ids(
    m,
    [("repeat", 0, 2), ("repeat", 3, 6), ("repeat", 7, 11), ("repeat", 12, 17)],
    "BBB1111aaaaa@@@@@@",
  )
  // matches multiple repeats with non-repeats in-between
  let m = run_repeat("2818BBBbzsdf1111@*&@!aaaaaEUDA@@@@@@1729")
  assert_match_ids(
    m,
    [
      ("repeat", 4, 6),
      ("repeat", 12, 15),
      ("repeat", 21, 25),
      ("repeat", 30, 35),
    ],
    "2818BBBbzsdf1111@*&@!aaaaaEUDA@@@@@@1729",
  )
  let bases = m.map(mm => {
    match mm {
      Repeat(r) => r.base_token
      _ => fail("expected repeat match")
    }
  })
  assert_eq(bases, ["B", "1", "a", "@"], msg="base tokens")

  // multi-character repeats
  let cases = [("abab", "ab"), ("aabaab", "aab"), ("abababab", "ab")]
  for row in cases {
    let (pattern, base) = row
    let m = run_repeat(pattern)
    assert_match_ids(
      m,
      [("repeat", 0, pattern.to_array().length() - 1)],
      pattern,
    )
    match m[0] {
      Repeat(r) =>
        assert_eq(r.base_token, base, msg="\{pattern}: base == \{base}")
      _ => fail("expected repeat match")
    }
  }
}

// ---------------------------------------------------------------------------
// 官方向量：regex matching
// ---------------------------------------------------------------------------

///|
test "official: regex matching" {
  for pw in ["1922", "2017"] {
    let m = regex_match(pw.to_array())
    assert_match_ids(m, [("regex", 0, 3)], pw)
    match m[0] {
      Regex(r) => assert_eq(r.regex_name, "recent_year", msg="recent_year")
      _ => fail("expected regex match")
    }
  }
}

// ---------------------------------------------------------------------------
// 官方向量：date matching
// ---------------------------------------------------------------------------

///|
test "official: date matching" {
  let dm = (pw : String) => date_match(pw.to_array(), 2026)
  // matches dates that use each separator
  for sep in ["", " ", "-", "/", "\\", "_", "."] {
    let password = "13\{sep}2\{sep}1921"
    let m = dm(password)
    assert_match_ids(
      m,
      [("date", 0, password.to_array().length() - 1)],
      password,
    )
    match m[0] {
      Date(d) => {
        assert_eq(d.separator, sep, msg="separator == \{sep}")
        assert_eq(d.year, 1921, msg="year == 1921")
        assert_eq(d.month, 2, msg="month == 2")
        assert_eq(d.day, 13, msg="day == 13")
      }
      _ => fail("expected date match")
    }
  }
  // matches dates with mdy/dmy/ymd/ydm formats
  for order in ["mdy", "dmy", "ymd", "ydm"] {
    let password = order
      .replace(old="y", new="88")
      .replace(old="m", new="8")
      .replace(old="d", new="8")
    let m = dm(password)
    assert_match_ids(
      m,
      [("date", 0, password.to_array().length() - 1)],
      password,
    )
    match m[0] {
      Date(d) => {
        assert_eq(d.separator, "", msg="separator == ''")
        assert_eq(d.year, 1988, msg="year == 1988")
        assert_eq(d.month, 8, msg="month == 8")
        assert_eq(d.day, 8, msg="day == 8")
      }
      _ => fail("expected date match")
    }
  }
  // matches the date with year closest to REFERENCE_YEAR when ambiguous
  let m = dm("111504")
  match m[0] {
    Date(d) => {
      assert_eq(d.year, 2004, msg="picks '04' -> 2004 as year, not '1504'")
      assert_eq(d.month, 11, msg="month == 11")
      assert_eq(d.day, 15, msg="day == 15")
    }
    _ => fail("expected date match")
  }
  // matches explicit dates
  let rows = [(1, 1, 1999), (11, 8, 2000), (9, 12, 2005), (22, 11, 1551)]
  for row in rows {
    let (day, month, year) = row
    let password = "\{year}\{month}\{day}"
    match dm(password)[0] {
      Date(d) => assert_eq(d.year, year, msg="year == \{year}")
      _ => fail("expected date match for \{password}")
    }
    let password = "\{year}.\{month}.\{day}"
    match dm(password)[0] {
      Date(d) => {
        assert_eq(d.separator, ".", msg="separator == .")
        assert_eq(d.year, year, msg="year == \{year}")
      }
      _ => fail("expected date match for \{password}")
    }
  }
  // matches zero-padded dates
  match dm("02/02/02")[0] {
    Date(d) => {
      assert_eq(d.separator, "/", msg="separator == /")
      assert_eq(d.year, 2002, msg="year == 2002")
      assert_eq(d.month, 2, msg="month == 2")
      assert_eq(d.day, 2, msg="day == 2")
    }
    _ => fail("expected date match")
  }
  // matches embedded dates
  for variant in genpws("1/1/91", ["", "a", "ab"], ["", "!"]) {
    let (password, i, j) = variant
    let m = dm(password)
    assert_match_ids(m, [("date", i, j)], "embedded \{password}")
    match m[0] {
      Date(d) => {
        assert_eq(d.year, 1991, msg="year == 1991")
        assert_eq(d.month, 1, msg="month == 1")
        assert_eq(d.day, 1, msg="day == 1")
      }
      _ => fail("expected date match")
    }
  }
  // matches overlapping dates
  let m = dm("12/20/1991.12.20")
  assert_match_ids(m, [("date", 0, 9), ("date", 6, 15)], "overlapping dates")
  match m[0] {
    Date(d) => {
      assert_eq(d.separator, "/", msg="separator == /")
      assert_eq(d.year, 1991, msg="year == 1991")
      assert_eq(d.month, 12, msg="month == 12")
      assert_eq(d.day, 20, msg="day == 20")
    }
    _ => fail("expected date match")
  }
  // matches dates padded by non-ambiguous digits
  let m = dm("912/20/919")
  assert_match_ids(m, [("date", 1, 8)], "912/20/919")
  match m[0] {
    Date(d) => {
      assert_eq(d.separator, "/", msg="separator == /")
      assert_eq(d.year, 1991, msg="year == 1991")
      assert_eq(d.month, 12, msg="month == 12")
      assert_eq(d.day, 20, msg="day == 20")
    }
    _ => fail("expected date match")
  }
}

// ---------------------------------------------------------------------------
// 官方向量：omnimatch
// ---------------------------------------------------------------------------

///|
test "official: omnimatch" {
  let matcher = Omnimatcher::new(Map([]), 2026)
  assert_eq(matcher.run("").length(), 0)
  let password = "r0sebudmaelstrom11/20/91aaaa"
  let matches = matcher.run(password)
  let cases = [
    ("dictionary", 0, 6),
    ("dictionary", 7, 15),
    ("date", 16, 23),
    ("repeat", 24, 27),
  ]
  for row in cases {
    let (pattern, i, j) = row
    let mut found = false
    for m in matches {
      if m.start_index() == i && m.end_index() == j && m.pattern() == pattern {
        found = true
      }
    }
    assert_true(
      found,
      msg="\{password}: should match \{pattern} at [\{i}, \{j}]",
    )
  }
}
