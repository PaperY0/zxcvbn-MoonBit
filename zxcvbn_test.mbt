///|
/// 词典数据测试（2026-09-23 修正：数据源从原始 txt 改为 frequency_lists.coffee）。
///
/// 背景：上游运行时加载的是 `src/frequency_lists.coffee`（经 build_frequency_lists.py
/// 四道处理：跨词典去重 / 短稀词剔除 / 逗号引号剔除 / 30000 等截断），最终规模
/// 30000/30000/3712/983/10000/19160，与 zxcvbn-rs 常量逐词一致。本项目嵌入的是
/// 同一份数据（生成时双源断言），因此 rank 与上游/zxcvbn-rs 完全一致——
/// 这是官方向量与差分对拍能通过的前提。
test "frequency data: sizes match upstream filtered lists (not raw txt)" {
  // 若这些数字变回 47023/100000/4275/1219/88799/39070，说明嵌错了原始 txt
  debug_inspect(@zxcvbn.passwords_list().length(), content="30000")
  debug_inspect(@zxcvbn.english_wikipedia_list().length(), content="30000")
  debug_inspect(@zxcvbn.female_names_list().length(), content="3712")
  debug_inspect(@zxcvbn.male_names_list().length(), content="983")
  debug_inspect(@zxcvbn.surnames_list().length(), content="10000")
  debug_inspect(@zxcvbn.us_tv_and_film_list().length(), content="19160")
}

///|
test "frequency data: first/last entries match upstream coffee order" {
  let p = @zxcvbn.passwords_list()
  debug_inspect(p[0], content="\"123456\"")
  debug_inspect(p[1], content="\"password\"")
  debug_inspect(p[29999], content="\"geekboy\"") // 截断边界：第 30000 个词
  debug_inspect(@zxcvbn.english_wikipedia_list()[0], content="\"the\"")
  debug_inspect(@zxcvbn.surnames_list()[0], content="\"smith\"")
  debug_inspect(@zxcvbn.female_names_list()[0], content="\"mary\"")
  debug_inspect(@zxcvbn.male_names_list()[0], content="\"james\"")
  debug_inspect(@zxcvbn.us_tv_and_film_list()[0], content="\"you\"")
}

///|
test "frequency data: cross-dictionary dedup keeps lowest-rank list" {
  // michael/james/thomas 在 raw passwords 与 surnames 里都有，但去重后只在
  // male_names（在那里 rank 更低）——与上游 filter_frequency_lists 语义一致
  match @zxcvbn.ranked_lookup("michael") {
    Some((@zxcvbn.Dictionary::MaleNames, rank)) =>
      debug_inspect(rank, content="4")
    _ => fail("expected Some((MaleNames, 4))")
  }
  match @zxcvbn.ranked_lookup("james") {
    Some((@zxcvbn.Dictionary::MaleNames, rank)) =>
      debug_inspect(rank, content="1")
    _ => fail("expected Some((MaleNames, 1))")
  }
  match @zxcvbn.ranked_lookup("jennifer") {
    Some((@zxcvbn.Dictionary::FemaleNames, rank)) =>
      debug_inspect(rank, content="6")
    _ => fail("expected Some((FemaleNames, 6))")
  }
  // 去重的另一面：passwords 表里不应再出现这些名字
  let pw = @zxcvbn.build_ranked_dict(@zxcvbn.passwords_list())
  debug_inspect(pw.get("michael"), content="None")
  debug_inspect(pw.get("james"), content="None")
}

///|
test "frequency data: short-rare words are filtered out" {
  // 'sex' 在 raw passwords 排名 4018，而 10**3=1000 <= 4018，按上游规则剔除；
  // 但它作为普通英文/影视词仍存在于其他表（us_tv_and_film）
  let pw = @zxcvbn.build_ranked_dict(@zxcvbn.passwords_list())
  debug_inspect(pw.get("sex"), content="None")
  match @zxcvbn.ranked_lookup("sex") {
    Some((@zxcvbn.Dictionary::UsTvAndFilm, _)) => ()
    _ => fail("expected sex to live in UsTvAndFilm")
  }
}

///|
test "core regex: supports POSIX digit class, alternation and find" {
  // 注意：MoonBit core 的 Regex 不支持 \d，须用 POSIX 类 [[:digit:]]（ASCII 语义）。
  let year_re = @string.Regex::unsafe_from_string(
    "19[[:digit:]][[:digit:]]|20[[:digit:]][[:digit:]]",
  )
  let hits : Array[String] = []
  for m in @string.Regex::find(year_re, "born 1984 died 2017 x9999") {
    hits.push(m.content().to_owned())
  }
  debug_inspect(hits, content="[\"1984\", \"2017\"]")
}
