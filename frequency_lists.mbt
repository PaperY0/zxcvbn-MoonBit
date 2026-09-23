///|
/// 词典标识。命名与 zxcvbn-rs 的 `DictionaryType` 对齐，便于差分对拍时对照。
pub enum Dictionary {
  Passwords
  English
  FemaleNames
  MaleNames
  Surnames
  UsTvAndFilm
  UserInputs
} derive(Eq, Debug)

///|
/// 由有序词表构建 rank 表。
///
/// rank 为 1-based 行序；重复词**后者覆盖前者**——与上游 `build_ranked_dict`
/// （JS 对象逐个赋值）及 zxcvbn-rs（HashMap `collect`）的语义保持一致。
pub fn build_ranked_dict(words : Array[String]) -> Map[String, Int] {
  let m : Map[String, Int] = Map([])
  let mut i = 0
  while i < words.length() {
    m[words[i]] = i + 1
    i += 1
  }
  m
}

///|
/// 6 个内置频率词典，首次使用时惰性构建。
/// 数据本体在 `frequency_data.mbt`（由 tools/gen_dictionaries.py 生成）。
let passwords_dict : Lazy[Map[String, Int]] = Lazy(() => {
  build_ranked_dict(passwords_list())
})

///|
let english_dict : Lazy[Map[String, Int]] = Lazy(() => {
  build_ranked_dict(english_wikipedia_list())
})

///|
let female_names_dict : Lazy[Map[String, Int]] = Lazy(() => {
  build_ranked_dict(female_names_list())
})

///|
let male_names_dict : Lazy[Map[String, Int]] = Lazy(() => {
  build_ranked_dict(male_names_list())
})

///|
let surnames_dict : Lazy[Map[String, Int]] = Lazy(() => {
  build_ranked_dict(surnames_list())
})

///|
let us_tv_and_film_dict : Lazy[Map[String, Int]] = Lazy(() => {
  build_ranked_dict(us_tv_and_film_list())
})

///|
/// 在全部内置词典中查词，返回 `(词典, rank)`。
///
/// 查询顺序与上游 `RANKED_DICTIONARIES` 的构造顺序一致：
/// passwords → english → female_names → male_names → surnames → us_tv_and_film。
/// 惰性求值短路：在靠前的词典命中时不会强制构建后续词典。
pub fn ranked_lookup(word : String) -> (Dictionary, Int)? {
  let dicts : Array[(Lazy[Map[String, Int]], Dictionary)] = [
    (passwords_dict, Passwords),
    (english_dict, English),
    (female_names_dict, FemaleNames),
    (male_names_dict, MaleNames),
    (surnames_dict, Surnames),
    (us_tv_and_film_dict, UsTvAndFilm),
  ]
  for pair in dicts {
    match pair.0.force().get(word) {
      Some(r) => return Some((pair.1, r))
      None => ()
    }
  }
  None
}
