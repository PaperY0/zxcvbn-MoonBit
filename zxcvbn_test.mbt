///|
/// 去风险测试（动手第一天前跑通）：
/// 1. 2.2 MB 词典数据能被 MoonBit 编译、解析、建表；
/// 2. rank 语义与上游一致（行序、常见密码位置）；
/// 3. core 自带 Regex 能表达上游的正则子集（\d、字母类）。
test "frequency data: list sizes match upstream txt line counts" {
  inspect(@zxcvbn.passwords_list().length(), content="47023")
  inspect(@zxcvbn.english_wikipedia_list().length(), content="100000")
  inspect(@zxcvbn.female_names_list().length(), content="4275")
  inspect(@zxcvbn.male_names_list().length(), content="1219")
  inspect(@zxcvbn.surnames_list().length(), content="88799")
  inspect(@zxcvbn.us_tv_and_film_list().length(), content="39070")
}

///|
test "frequency data: first entries match upstream order" {
  let p = @zxcvbn.passwords_list()
  inspect(p[0], content="123456")
  inspect(p[1], content="password")
  inspect(p[2], content="12345678")
  let w = @zxcvbn.english_wikipedia_list()
  inspect(w[0], content="the")
  inspect(w[1], content="of")
}

///|
test "ranked dict: rank is 1-based line order" {
  let d = @zxcvbn.build_ranked_dict(@zxcvbn.passwords_list())
  inspect(d.get("123456"), content="Some(1)")
  inspect(d.get("password"), content="Some(2)")
  inspect(d.get("not_a_real_password_xyz"), content="None")
}

///|
test "ranked_lookup: finds the right dictionary" {
  match @zxcvbn.ranked_lookup("password") {
    Some((@zxcvbn.Dictionary::Passwords, rank)) => inspect(rank, content="2")
    _ => fail("expected Some((Passwords, 2))")
  }
  match @zxcvbn.ranked_lookup("the") {
    Some((@zxcvbn.Dictionary::English, rank)) => inspect(rank, content="1")
    _ => fail("expected Some((English, 1))")
  }
  match @zxcvbn.ranked_lookup("zzz_not_in_any_dict_zzz") {
    None => ()
    _ => fail("expected None")
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
    hits.push(m.content().to_string())
  }
  inspect(hits, content="[1984, 2017]")
}
