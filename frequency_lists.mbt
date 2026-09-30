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
pub extend Dictionary with Eq::{equal, not_equal}

///|
pub extend Dictionary with @debug.Debug::{to_repr}

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

///|
/// 全部内置频率词典，顺序与上游 `RANKED_DICTIONARIES` 的构造顺序一致。
/// 匹配器（dictionary_match / reverse_dictionary_match / l33t_match）按这个顺序遍历。
pub let builtin_dictionaries : Array[(Dictionary, Lazy[Map[String, Int]])] = [
  (Passwords, passwords_dict),
  (English, english_dict),
  (FemaleNames, female_names_dict),
  (MaleNames, male_names_dict),
  (Surnames, surnames_dict),
  (UsTvAndFilm, us_tv_and_film_dict),
]

///|
/// 内置词典中最长词条的**字符数**（按 Unicode 标量值计）。
///
/// `dictionary_match` 只需枚举到这个长度：更长的子串不可能命中任何词条。
/// 这是与上游**语义完全等价**的裁剪（上游枚举全部长度，结果必然为空），
/// 但把词典匹配从 O(n²) 次哈希查询降到 O(n × 最长词长)，长密码收益巨大。
pub let max_dictionary_word_length : Lazy[Int] = Lazy(() => {
  let lists : Array[Array[String]] = [
    passwords_list(),
    english_wikipedia_list(),
    female_names_list(),
    male_names_list(),
    surnames_list(),
    us_tv_and_film_list(),
  ]
  let mut longest = 1
  for list in lists {
    for word in list {
      let len = word.to_array().length()
      if len > longest {
        longest = len
      }
    }
  }
  longest
})

///|
/// `frequency_lists.coffee` 在 ASCII 小写字母域内过滤，但词典里确实存在少量
/// 非 ASCII 词条。这里把它们转成 ASCII 小写以对齐 `Array[Char]` 的匹配口径。
pub fn to_ascii_lower(chars : Array[Char]) -> Array[Char] {
  chars.map(c => c.to_ascii_lowercase())
}
