// 模式匹配：omnimatch 的 8 个匹配器 + 公共 Match 类型。
//
// 移植来源：dropbox/zxcvbn `src/matching.coffee`（MIT, (c) Dropbox, Inc.）
// 结构参考：shssoichiro/zxcvbn-rs `src/matching/mod.rs`（MIT）
//
// 与上游的两处刻意差异（README 已声明，都是修正）：
//   1. 所有下标按 **Unicode 标量值** 计（MoonBit 的 Char 即标量值），而上游按
//      UTF-16 码元。上游在 HIV 密码上出过经典的 UTF-16 边界 bug，这里从根上避免。
//      代价是 `token.length` 与上游的 `String::length` 在含非 BMP 字符时不同。
//   2. 词典匹配枚举长度上限为 `max_dictionary_word_length`，语义等价但避免了
//      对不可能命中的超长子串做 O(n²) 次查询。

// ---------------------------------------------------------------------------
// Match 类型
// ---------------------------------------------------------------------------

///|
/// 词典标识。命名与上游 `frequency_lists` 的键一致，便于与官方向量/差分结果对照。
/// （类型定义在 `frequency_lists.mbt`，此处 re-export 语义上属于匹配层输入。）

///|
/// 一次模式匹配。
///
/// 上游用动态对象承载所有字段；这里按 zxcvbn-rs 的强类型范式拆成 enum + 每模式
/// struct，让编译器捕获"某模式没有该字段"一类错误。
pub enum Match {
  /// 未被任何模式覆盖的区间（DP 的兜底项）
  Bruteforce(BruteforceMatch)
  /// 词典（含反向、l33t 变体）
  Dictionary(DictionaryMatch)
  /// 键盘空间模式
  Spatial(SpatialMatch)
  /// 重复模式（`abcabcabc`）
  Repeat(RepeatMatch)
  /// 序列模式（`abc` / `123` / `97531`）
  Sequence(SequenceMatch)
  /// 正则模式（`recent_year`）
  Regex(RegexMatch)
  /// 日期模式
  Date(DateMatch)
} derive(Eq, Debug)

///|
pub extend Match with Eq::{equal, not_equal}

///|
pub extend Match with @debug.Debug::{to_repr}

///|
/// 暴力匹配的区间。
pub struct BruteforceMatch {
  i : Int
  j : Int
  token : String
  mut guesses : Double
  mut guesses_log10 : Double
} derive(Eq, Debug)

///|
pub extend BruteforceMatch with Eq::{equal, not_equal}

///|
pub extend BruteforceMatch with @debug.Debug::{to_repr}

///|
/// 词典匹配。`rank` 为 1-based 行序；`l33t`/`reversed` 标记变体；
/// `sub` 记录该匹配实际用到的 l33t 替换（subbed_char → 原字母）。
pub struct DictionaryMatch {
  mut i : Int
  mut j : Int
  mut token : String
  /// 查表用的（已转小写的）命中词
  matched_word : String
  rank : Int
  dictionary_name : Dictionary
  mut reversed : Bool
  l33t : Bool
  sub : Array[(Char, Char)]
  mut guesses : Double
  mut guesses_log10 : Double
} derive(Eq, Debug)

///|
pub extend DictionaryMatch with Eq::{equal, not_equal}

///|
pub extend DictionaryMatch with @debug.Debug::{to_repr}

///|
/// 键盘空间匹配。`turns` 为转向次数，`shifted_count` 为按了 Shift 的键数。
pub struct SpatialMatch {
  i : Int
  j : Int
  token : String
  /// 图名：`qwerty` / `dvorak` / `keypad` / `mac_keypad`
  graph : String
  turns : Int
  shifted_count : Int
  mut guesses : Double
  mut guesses_log10 : Double
} derive(Eq, Debug)

///|
pub extend SpatialMatch with Eq::{equal, not_equal}

///|
pub extend SpatialMatch with @debug.Debug::{to_repr}

///|
/// 重复匹配。`base_matches` 是对 base_token 递归 omnimatch 的结果。
pub struct RepeatMatch {
  i : Int
  j : Int
  token : String
  base_token : String
  base_guesses : Double
  base_matches : Array[Match]
  repeat_count : Int
  mut guesses : Double
  mut guesses_log10 : Double
} derive(Eq, Debug)

///|
pub extend RepeatMatch with Eq::{equal, not_equal}

///|
pub extend RepeatMatch with @debug.Debug::{to_repr}

///|
/// 序列匹配。`sequence_space` 为序列空间大小（lower/upper=26，digits=10）。
pub struct SequenceMatch {
  i : Int
  j : Int
  token : String
  /// `lower` / `upper` / `digits` / `unicode`
  sequence_name : String
  sequence_space : Int
  ascending : Bool
  mut guesses : Double
  mut guesses_log10 : Double
} derive(Eq, Debug)

///|
pub extend SequenceMatch with Eq::{equal, not_equal}

///|
pub extend SequenceMatch with @debug.Debug::{to_repr}

///|
/// 正则匹配。目前只有 `recent_year`。
pub struct RegexMatch {
  i : Int
  j : Int
  token : String
  regex_name : String
  mut guesses : Double
  mut guesses_log10 : Double
} derive(Eq, Debug)

///|
pub extend RegexMatch with Eq::{equal, not_equal}

///|
pub extend RegexMatch with @debug.Debug::{to_repr}

///|
/// 日期匹配。上游不做真日期解析（`feb 31st` 合法、不查闰年）。
pub struct DateMatch {
  i : Int
  j : Int
  token : String
  /// 分隔符；无分隔符（如 `1191`）时为空串
  separator : String
  year : Int
  month : Int
  day : Int
  mut guesses : Double
  mut guesses_log10 : Double
} derive(Eq, Debug)

///|
pub extend DateMatch with Eq::{equal, not_equal}

///|
pub extend DateMatch with @debug.Debug::{to_repr}

///|
/// 匹配起点（闭区间，Unicode 标量值下标）。
pub fn Match::start_index(self : Match) -> Int {
  match self {
    Bruteforce(m) => m.i
    Dictionary(m) => m.i
    Spatial(m) => m.i
    Repeat(m) => m.i
    Sequence(m) => m.i
    Regex(m) => m.i
    Date(m) => m.i
  }
}

///|
/// 匹配终点（闭区间，Unicode 标量值下标）。
pub fn Match::end_index(self : Match) -> Int {
  match self {
    Bruteforce(m) => m.j
    Dictionary(m) => m.j
    Spatial(m) => m.j
    Repeat(m) => m.j
    Sequence(m) => m.j
    Regex(m) => m.j
    Date(m) => m.j
  }
}

///|
/// 命中的原文字符串。
pub fn Match::token(self : Match) -> String {
  match self {
    Bruteforce(m) => m.token
    Dictionary(m) => m.token
    Spatial(m) => m.token
    Repeat(m) => m.token
    Sequence(m) => m.token
    Regex(m) => m.token
    Date(m) => m.token
  }
}

///|
/// 模式名（与上游 pattern 字符串一致）。
pub fn Match::pattern(self : Match) -> String {
  match self {
    Bruteforce(_) => "bruteforce"
    Dictionary(_) => "dictionary"
    Spatial(_) => "spatial"
    Repeat(_) => "repeat"
    Sequence(_) => "sequence"
    Regex(_) => "regex"
    Date(_) => "date"
  }
}

///|
/// 匹配长度（标量值个数）。
pub fn Match::span_length(self : Match) -> Int {
  self.end_index() - self.start_index() + 1
}

///|
/// 已缓存的猜测数（0 表示尚未计算）。
pub fn Match::guesses(self : Match) -> Double {
  match self {
    Bruteforce(m) => m.guesses
    Dictionary(m) => m.guesses
    Spatial(m) => m.guesses
    Repeat(m) => m.guesses
    Sequence(m) => m.guesses
    Regex(m) => m.guesses
    Date(m) => m.guesses
  }
}

///|
/// `log10(guesses)`（上游用于 feedback 文案）。
pub fn Match::guesses_log10(self : Match) -> Double {
  match self {
    Bruteforce(m) => m.guesses_log10
    Dictionary(m) => m.guesses_log10
    Spatial(m) => m.guesses_log10
    Repeat(m) => m.guesses_log10
    Sequence(m) => m.guesses_log10
    Regex(m) => m.guesses_log10
    Date(m) => m.guesses_log10
  }
}

///|
/// 写入猜测数缓存（DP 会多次调用 `estimate_guesses`，缓存避免重复计算）。
pub fn Match::set_guesses(self : Match, guesses : Double) -> Unit {
  match self {
    Bruteforce(m) => m.guesses = guesses
    Dictionary(m) => m.guesses = guesses
    Spatial(m) => m.guesses = guesses
    Repeat(m) => m.guesses = guesses
    Sequence(m) => m.guesses = guesses
    Regex(m) => m.guesses = guesses
    Date(m) => m.guesses = guesses
  }
}

///|
/// 写入 `log10(guesses)`。
pub fn Match::set_guesses_log10(self : Match, log10 : Double) -> Unit {
  match self {
    Bruteforce(m) => m.guesses_log10 = log10
    Dictionary(m) => m.guesses_log10 = log10
    Spatial(m) => m.guesses_log10 = log10
    Repeat(m) => m.guesses_log10 = log10
    Sequence(m) => m.guesses_log10 = log10
    Regex(m) => m.guesses_log10 = log10
    Date(m) => m.guesses_log10 = log10
  }
}

///|
/// 生成调试用的单行摘要（不含 guesses，避免噪声）。
pub fn Match::describe(self : Match) -> String {
  "\{self.pattern()}(\{self.start_index()}, \{self.end_index()}) \{self.token()}"
}

// ---------------------------------------------------------------------------
// 工具函数（对应上游 `matching.empty/extend/translate/mod/sorted`）
// ---------------------------------------------------------------------------

///|
/// 上游 `matching.extend`：`lst.push.apply(lst, lst2)`。
fn[T] extend_matches(lst : Array[T], lst2 : Array[T]) -> Unit {
  for item in lst2 {
    lst.push(item)
  }
}

///|
/// 上游 `matching.translate`：按 chr_map 替换字符。
fn translate(chars : Array[Char], chr_map : Map[Char, Char]) -> Array[Char] {
  chars.map(c => {
    match chr_map.get(c) {
      Some(replacement) => replacement
      None => c
    }
  })
}

///|
/// 上游 `matching.mod`：对负数也正确的取模。
pub fn mod_impl(n : Int, m : Int) -> Int {
  (n % m + m) % m
}

///|
/// 上游 `matching.sorted`：按 `i` 主序、`j` 次序排序。
///
/// 注意：这里**不**按 guesses 排序（上游同样如此）。DP 内部会按 j 分区再按 i
/// 排序，所以全局顺序不影响结果，但保持确定性输出有助于测试与调试。
pub fn sort_matches(matches : Array[Match]) -> Array[Match] {
  matches.sort_by((m1, m2) => {
    if m1.start_index() != m2.start_index() {
      m1.start_index() - m2.start_index()
    } else {
      m1.end_index() - m2.end_index()
    }
  })
  matches
}

///|
/// 把 char 数组的闭区间 `[i, j]` 转成字符串。
fn slice_to_string(chars : Array[Char], i : Int, j : Int) -> String {
  String::from_array(chars[i:j + 1])
}

///|
/// 是否某个字符是 ASCII 小写字母。
fn is_lower(c : Char) -> Bool {
  c.is_ascii_lowercase()
}

///|
/// 是否某个字符是 ASCII 大写字母。
fn is_upper(c : Char) -> Bool {
  c.is_ascii_uppercase()
}

///|
/// 是否某个字符是 ASCII 数字。
fn is_digit(c : Char) -> Bool {
  c.is_ascii_digit()
}

///|
/// 上游 `scoring.START_UPPER` 等四个正则的字符级等价实现。
fn all_ascii_lower(chars : Array[Char]) -> Bool {
  for c in chars {
    if !is_lower(c) {
      return false
    }
  }
  true
}

///|
fn all_ascii_upper(chars : Array[Char]) -> Bool {
  for c in chars {
    if !is_upper(c) {
      return false
    }
  }
  true
}

///|
fn all_ascii_digit(chars : Array[Char]) -> Bool {
  for c in chars {
    if !is_digit(c) {
      return false
    }
  }
  true
}

// ---------------------------------------------------------------------------
// omnimatch：把 8 个匹配器跑一遍
// ---------------------------------------------------------------------------

///|
/// 一次 omnimatch 需要的上下文（上游用模块级全局变量传递用户输入词典）。
pub struct Omnimatcher {
  dictionaries : Array[(Dictionary, Map[String, Int])]
  max_word_length : Int
  reference_year : Int
} derive(Eq, Debug)

///|
pub extend Omnimatcher with Eq::{equal, not_equal}

///|
pub extend Omnimatcher with @debug.Debug::{to_repr}

///|
/// 构造 omnimatch 上下文。`user_inputs` 已由调用方小写化并建表。
pub fn Omnimatcher::new(
  user_inputs : Map[String, Int],
  reference_year : Int,
) -> Omnimatcher {
  // 用户词典：沿用上游 sanitize 后的语义（全部小写、按出现顺序 rank）。
  // 用户词典不参与 max_word_length 的全局上限裁剪，单独按其最长词放宽。
  let builtin = builtin_dictionaries
  let dicts : Array[(Dictionary, Map[String, Int])] = []
  for pair in builtin {
    dicts.push((pair.0, pair.1.force()))
  }
  dicts.push((Dictionary::UserInputs, user_inputs))
  let mut max_len = max_dictionary_word_length.force()
  for word in user_inputs.keys() {
    let len = word.to_array().length()
    if len > max_len {
      max_len = len
    }
  }
  { dictionaries: dicts, max_word_length: max_len, reference_year, }
}

///|
/// 上游 `omnimatch(password)`：跑完全部匹配器后按 `sorted` 排序。
pub fn Omnimatcher::run(self : Omnimatcher, password : String) -> Array[Match] {
  full_match(
    password,
    self.dictionaries,
    self.max_word_length,
    l33t_table,
    self.reference_year,
  )
}

// ---------------------------------------------------------------------------
// 词典匹配 / 反向词典匹配
// ---------------------------------------------------------------------------

///|
/// 对一个密码跑完全部 8 个匹配器（`Omnimatcher::run` 与 `repeat_match` 的递归分析共用）。
fn full_match(
  password : String,
  dictionaries : Array[(Dictionary, Map[String, Int])],
  max_word_length : Int,
  table : Map[Char, Array[Char]],
  reference_year : Int,
) -> Array[Match] {
  let chars = password.to_array()
  let matches : Array[Match] = []
  extend_matches(
    matches,
    dictionary_match(chars, dictionaries, max_word_length),
  )
  extend_matches(
    matches,
    reverse_dictionary_match(chars, dictionaries, max_word_length),
  )
  extend_matches(
    matches,
    l33t_match(chars, dictionaries, table, max_word_length),
  )
  extend_matches(matches, spatial_match(chars, all_graphs()))
  extend_matches(
    matches,
    repeat_match(chars, dictionaries, max_word_length, table, reference_year),
  )
  extend_matches(matches, sequence_match(chars))
  extend_matches(matches, regex_match(chars))
  extend_matches(matches, date_match(chars, reference_year))
  sort_matches(matches)
}

///|
/// 上游 `dictionary_match`。
pub fn dictionary_match(
  password : Array[Char],
  dictionaries : Array[(Dictionary, Map[String, Int])],
  max_word_length : Int,
) -> Array[Match] {
  let password_lower = password.map(c => c.to_ascii_lowercase())
  dictionary_match_inner(
    password, password_lower, dictionaries, max_word_length,
  )
}

///|
/// 词典匹配主体。`password_lower` 由调用方传入（l33t 匹配要传"替换后"的小写形式）。
pub fn dictionary_match_inner(
  password : Array[Char],
  password_lower : Array[Char],
  dictionaries : Array[(Dictionary, Map[String, Int])],
  max_word_length : Int,
) -> Array[Match] {
  let len = password.length()
  let matches : Array[Match] = []
  // 长度上限裁剪（见文件头说明）：不可能命中的长度不枚举。
  let limit = if max_word_length < len { max_word_length } else { len }
  for entry in dictionaries {
    let (dict_name, ranked) = entry
    let mut i = 0
    while i < len {
      let j_max = if i + limit < len { i + limit } else { len - 1 }
      let mut j = i
      while j <= j_max {
        let word = slice_to_string(password_lower, i, j)
        // get_from_string 接受 StringView，避免把 word 移进 Map 查询
        match ranked.get_from_string(word) {
          Some(rank) =>
            matches.push(
              Match::Dictionary({
                i,
                j,
                token: slice_to_string(password, i, j),
                matched_word: word,
                rank,
                dictionary_name: dict_name,
                reversed: false,
                l33t: false,
                sub: [],
                guesses: 0.0,
                guesses_log10: 0.0,
              }),
            )
          None => ()
        }
        j += 1
      }
      i += 1
    }
  }
  sort_matches(matches)
}

///|
/// 上游 `reverse_dictionary_match`。
pub fn reverse_dictionary_match(
  password : Array[Char],
  dictionaries : Array[(Dictionary, Map[String, Int])],
  max_word_length : Int,
) -> Array[Match] {
  let len = password.length()
  let reversed = password.rev()
  let reversed_lower = reversed.map(c => c.to_ascii_lowercase())
  let matches = dictionary_match_inner(
    reversed, reversed_lower, dictionaries, max_word_length,
  )
  for m in matches {
    match m {
      Dictionary(d) => {
        // 坐标映射回原串：i' = len-1-j, j' = len-1-i
        let (orig_i, orig_j) = (d.i, d.j)
        d.i = len - 1 - orig_j
        d.j = len - 1 - orig_i
        d.token = slice_to_string(password, d.i, d.j)
        d.reversed = true
      }
      _ => ()
    }
  }
  sort_matches(matches)
}

// ---------------------------------------------------------------------------
// l33t 替换
// ---------------------------------------------------------------------------

///|
/// 整数绝对值（避免为此单独依赖 `moonbitlang/core/int`）。
fn abs_int(n : Int) -> Int {
  if n < 0 {
    -n
  } else {
    n
  }
}

///|
/// MoonBit 的数组切片（`arr[i:j]`）得到的是 `ArrayView[Char]`，
/// 而各分析帮例程序统一按 `Array[Char]` 接受。
fn view_to_array(view : ArrayView[Char]) -> Array[Char] {
  Array::from_iter(view.iter())
}

///|
/// 上游 `L33T_TABLE`：字母 → 常见 l33t 替换字符。
let l33t_table : Map[Char, Array[Char]] = Map([
  ('a', ['4', '@']),
  ('b', ['8']),
  ('c', ['(', '{', '[', '<']),
  ('e', ['3']),
  ('g', ['6', '9']),
  ('i', ['1', '!', '|']),
  ('l', ['1', '|', '7']),
  ('o', ['0']),
  ('s', ['$', '5']),
  ('t', ['+', '7']),
  ('x', ['%']),
  ('z', ['2']),
])

///|
/// 上游 `relevant_l33t_subtable`：只保留密码里真的出现了的替换支。
pub fn relevant_l33t_subtable(
  password : Array[Char],
  table : Map[Char, Array[Char]],
) -> Map[Char, Array[Char]] {
  let subtable : Map[Char, Array[Char]] = Map([])
  for pair in table.iter() {
    let (letter, subs) = pair
    let relevant = subs.filter(sub => password.contains(sub))
    if relevant.length() > 0 {
      subtable[letter] = relevant
    }
  }
  subtable
}

///|
/// 上游 `enumerate_l33t_subs`：枚举所有可能的 l33t 替换字典（带去重）。
fn enumerate_l33t_subs(
  table : Map[Char, Array[Char]],
) -> Array[Map[Char, Char]] {
  // Map 的迭代顺序未定义；为了让输出可复现，按键排序后枚举。
  let keys = table.keys().to_array()
  keys.sort()
  // subs 以关联数组（Array[(Char, Char)]）形式承载，最后转成 Map
  let subs : Array[Array[(Char, Char)]] = [[]]
  let mut key_index = 0
  while key_index < keys.length() {
    let first_key = keys[key_index]
    let l33t_chrs = match table.get(first_key) {
      Some(v) => v
      None => []
    }
    let next_subs : Array[Array[(Char, Char)]] = []
    for l33t_chr in l33t_chrs {
      for sub in subs {
        let mut dup_index = -1
        let mut i = 0
        while i < sub.length() {
          if sub[i].0 == l33t_chr {
            dup_index = i
            i = sub.length()
            break
          }
          i += 1
        }
        if dup_index == -1 {
          // 该替换字符尚未占用，直接扩展
          let sub_extension = sub.copy()
          sub_extension.push((l33t_chr, first_key))
          next_subs.push(sub_extension)
        } else {
          // 同一替换字符已被别的字母占用：生成"改投该字母"的备选
          let sub_alternative = sub.copy()
          ignore(sub_alternative.remove(dup_index))
          sub_alternative.push((l33t_chr, first_key))
          next_subs.push(sub)
          next_subs.push(sub_alternative)
        }
      }
    }
    // subs = dedup(next_subs)：原地替换，保持同一数组引用
    subs.clear()
    dedup_l33t_subs(next_subs).each(dup => subs.push(dup))
    key_index += 1
  }
  subs.map(assoc => Map(assoc))
}

///|
/// 上游 `dedup`：按排序后的关联串去重，保留首个。
fn dedup_l33t_subs(
  subs : Array[Array[(Char, Char)]],
) -> Array[Array[(Char, Char)]] {
  let seen : Map[String, Unit] = Map([])
  let out : Array[Array[(Char, Char)]] = []
  for sub in subs {
    let labels = sub.map(pair => "\{pair.0},\{pair.1}")
    labels.sort()
    let label = labels.join("-")
    match seen.get(label) {
      Some(_) => ()
      None => {
        seen[label] = ()
        out.push(sub)
      }
    }
  }
  out
}

///|
/// 上游 `l33t_match`。
pub fn l33t_match(
  password : Array[Char],
  dictionaries : Array[(Dictionary, Map[String, Int])],
  table : Map[Char, Array[Char]],
  max_word_length : Int,
) -> Array[Match] {
  let matches : Array[Match] = []
  for sub in enumerate_l33t_subs(relevant_l33t_subtable(password, table)) {
    // 角落情况：密码没有任何可用替换
    if sub.length() == 0 {
      continue
    }
    let subbed = translate(password, sub)
    let subbed_lower = subbed.map(c => c.to_ascii_lowercase())
    for
      m in dictionary_match_inner(
        subbed, subbed_lower, dictionaries, max_word_length,
      ) {
      match m {
        Dictionary(d) => {
          let token = slice_to_string(password, d.i, d.j)
          if token.to_lower() == d.matched_word {
            // 只保留真正发生了替换的匹配
            continue
          }
          // match_sub：该匹配实际用到的替换子集
          let match_sub : Array[(Char, Char)] = []
          for pair in sub.iter() {
            let (subbed_chr, chr) = pair
            if token.contains_char(subbed_chr) {
              match_sub.push((subbed_chr, chr))
            }
          }
          match_sub.sort_by((a, b) => a.0.to_int() - b.0.to_int())
          matches.push(
            Match::Dictionary({
              i: d.i,
              j: d.j,
              token,
              matched_word: d.matched_word,
              rank: d.rank,
              dictionary_name: d.dictionary_name,
              reversed: false,
              l33t: true,
              sub: match_sub,
              guesses: 0.0,
              guesses_log10: 0.0,
            }),
          )
        }
        _ => ()
      }
    }
  }
  // 过滤单字符 l33t 匹配以降噪（'1' 命中 'i'、'4' 命中 'a' 这类）
  let filtered = matches.filter(m => m.span_length() > 1)
  sort_matches(filtered)
}

// ---------------------------------------------------------------------------
// 键盘空间匹配
// ---------------------------------------------------------------------------

///|
/// 上游 `SHIFTED_RX` 的字符集合。
fn is_shifted_char(c : Char) -> Bool {
  let shifted : String = "~!@#$%^&*()_+QWERTYUIOP{}|ASDFGHJKL:\"ZXCVBNM<>?"
  shifted.contains_char(c)
}

///|
/// 上游 `spatial_match`。
pub fn spatial_match(
  password : Array[Char],
  graphs : Array[(String, Map[Char, Array[(Char, Char)?]])],
) -> Array[Match] {
  let matches : Array[Match] = []
  for entry in graphs {
    let (name, graph) = entry
    extend_matches(matches, spatial_match_helper(password, graph, name))
  }
  sort_matches(matches)
}

///|
/// 全部四个键盘图（顺序与上游 GRAPHS 一致）。
pub fn all_graphs() -> Array[(String, Map[Char, Array[(Char, Char)?]])] {
  graph_names.map(name => (name, get_graph(name)))
}

///|
/// 上游 `spatial_match_helper`。
fn spatial_match_helper(
  password : Array[Char],
  graph : Map[Char, Array[(Char, Char)?]],
  graph_name : String,
) -> Array[Match] {
  let matches : Array[Match] = []
  let len = password.length()
  let mut i = 0
  while i < len - 1 {
    let mut j = i + 1
    let mut last_direction : Int? = None
    let mut turns = 0
    let mut shifted_count = 0
    if (graph_name == "qwerty" || graph_name == "dvorak") &&
      is_shifted_char(password[i]) {
      // 起始字符本身是 Shift 形态
      shifted_count = 1
    }
    let mut stop = false
    while !stop {
      let prev_char = password[j - 1]
      let mut found = false
      let mut found_direction = -1
      let mut cur_direction = -1
      let adjacents : Array[(Char, Char)?] = match graph.get(prev_char) {
        Some(arcs) => arcs
        None => []
      }
      if j < len {
        let cur_char = password[j]
        for adj in adjacents {
          cur_direction += 1
          match adj {
            Some((unshifted, shifted)) => {
              // 等价于上游 adj.indexOf(cur_char)：先看未移位位，再看移位位
              let index : Int? = if cur_char == unshifted {
                Some(0)
              } else if cur_char == shifted {
                Some(1)
              } else {
                None
              }
              match index {
                Some(idx) => {
                  found = true
                  found_direction = cur_direction
                  if idx == 1 {
                    // 下标 1 表示该键是按 Shift 输入的
                    shifted_count += 1
                  }
                  if last_direction != Some(found_direction) {
                    // 起始时 last_direction 为 None，任何方向都算一次转向：
                    // 每个键盘模式都以一次转向开始。
                    turns += 1
                    last_direction = Some(found_direction)
                  }
                  stop = true
                  break
                }
                None => ()
              }
            }
            None => ()
          }
        }
      }
      if found && !stop {
        j += 1
      } else if found {
        // 内部循环因找到相邻键而退出：继续扩展 j
        stop = false
        j += 1
      } else {
        // 模式到此为止，记录（长度 1、2 的链不考虑）
        if j - i > 2 {
          matches.push(
            Match::Spatial({
              i,
              j: j - 1,
              token: slice_to_string(password, i, j - 1),
              graph: graph_name,
              turns,
              shifted_count,
              guesses: 0.0,
              guesses_log10: 0.0,
            }),
          )
        }
        i = j
        stop = true
      }
    }
  }
  matches
}

// ---------------------------------------------------------------------------
// 重复匹配
// ---------------------------------------------------------------------------

///|
/// 在 `p` 处是否存在"某个长度 L 的单元紧邻重复至少两次"。
/// `greedy` 为 true 时取最大可行 L，否则取最小。
/// 返回 `(块终止下标 j, 单元长度 L)`。
fn repeat_at(password : Array[Char], p : Int, greedy : Bool) -> (Int, Int)? {
  let len = password.length()
  let max_l = (len - p) / 2
  if max_l < 1 {
    return None
  }
  if greedy {
    let mut l = max_l
    while l >= 1 {
      let count = count_repeats(password, p, l)
      if count >= 2 {
        return Some((p + count * l - 1, l))
      }
      l -= 1
    }
    None
  } else {
    let mut l = 1
    while l <= max_l {
      let count = count_repeats(password, p, l)
      if count >= 2 {
        return Some((p + count * l - 1, l))
      }
      l += 1
    }
    None
  }
}

///|
/// 从 `p` 起，长度 L 的单元能连续重复多少次（至少 1）。
fn count_repeats(password : Array[Char], p : Int, l : Int) -> Int {
  let len = password.length()
  let mut count = 1
  let mut start = p + l
  while start + l <= len {
    let mut equal = true
    let mut k = 0
    while k < l {
      if password[start + k] != password[p + k] {
        equal = false
        k = l
        break
      }
      k += 1
    }
    if !equal {
      break
    }
    count += 1
    start += l
  }
  count
}

///|
/// 从 `start` 起找第一个可重复的位置（对应正则 `lastIndex` 语义）。
fn repeat_from(
  password : Array[Char],
  start : Int,
  greedy : Bool,
) -> (Int, Int, Int)? {
  let len = password.length()
  let mut p = start
  while p < len {
    match repeat_at(password, p, greedy) {
      Some((j_end, l)) => return Some((p, j_end, l))
      None => p += 1
    }
  }
  None
}

///|
/// 上游 `lazy_anchored = /^(.+?)\1+$/`：整串都能被某个最短单元整除重复时，
/// 返回该最短单元长度。替代正则反向引用的手写实现（MoonBit core 的正则不支持 `\1`）。
fn shortest_period(password : Array[Char], i : Int, j : Int) -> Int {
  let total = j - i + 1
  let mut l = 1
  while l <= total {
    if total % l == 0 && count_repeats(password, i, l) == total / l {
      return l
    }
    l += 1
  }
  total
}

///|
/// 上游 `repeat_match`。
pub fn repeat_match(
  password : Array[Char],
  dictionaries : Array[(Dictionary, Map[String, Int])],
  max_word_length : Int,
  table : Map[Char, Array[Char]],
  reference_year : Int,
) -> Array[Match] {
  let matches : Array[Match] = []
  let len = password.length()
  let mut last_index = 0
  let mut stop = false
  while last_index < len && !stop {
    // 上游分别用 greedy / lazy 两个正则找重复块，再比较谁覆盖更长
    let greedy = repeat_from(password, last_index, true)
    let lazy_match = repeat_from(password, last_index, false)
    match (greedy, lazy_match) {
      // 上游 `break unless greedy_match?`：没有可重复块就结束
      (None, _) | (_, None) => stop = true
      (Some(g), Some(l)) => {
        let use_greedy = g.1 - g.0 > l.1 - l.0
        let (i, j, base_token_len) = if use_greedy {
          // greedy 的重复串自身可能还是重复的（如 aabaab 里的 aab），
          // 用 anchored lazy 的思想取最短单元
          let period = shortest_period(password, g.0, g.1)
          (g.0, g.1, period)
        } else {
          (l.0, l.1, l.2)
        }
        let token = slice_to_string(password, i, j)
        let base_token = slice_to_string(password, i, i + base_token_len - 1)
        // 递归分析并打分 base_token
        let base_analysis = most_guessable_match_sequence(
          base_token,
          full_match(
            base_token, dictionaries, max_word_length, table, reference_year,
          ),
          reference_year,
        )
        matches.push(
          Match::Repeat({
            i,
            j,
            token,
            base_token,
            base_guesses: base_analysis.guesses,
            base_matches: base_analysis.sequence,
            repeat_count: token.to_array().length() /
            base_token.to_array().length(),
            guesses: 0.0,
            guesses_log10: 0.0,
          }),
        )
        last_index = j + 1
      }
    }
  }
  matches
}

// ---------------------------------------------------------------------------
// 序列匹配
// ---------------------------------------------------------------------------

///|
/// 上游 `max_delta`：允许的相邻字符码点差上限（支持 `9753` 这种跳跃）。
let max_delta = 5

///|
/// 上游 `sequence_match` 里的 `update`。
fn push_sequence_if_valid(
  result : Array[Match],
  password : Array[Char],
  i : Int,
  j : Int,
  delta : Int,
) -> Unit {
  if j - i > 1 || abs_int(delta) == 1 {
    if 0 < abs_int(delta) && abs_int(delta) <= max_delta {
      let token = slice_to_string(password, i, j)
      let token_chars = token.to_array()
      let (sequence_name, sequence_space) = if all_ascii_lower(token_chars) {
        ("lower", 26)
      } else if all_ascii_upper(token_chars) {
        ("upper", 26)
      } else if all_ascii_digit(token_chars) {
        ("digits", 10)
      } else {
        // 保守地仍按罗马字母表大小估计（可改进）
        ("unicode", 26)
      }
      result.push(
        Match::Sequence({
          i,
          j,
          token,
          sequence_name,
          sequence_space,
          ascending: delta > 0,
          guesses: 0.0,
          guesses_log10: 0.0,
        }),
      )
    }
  }
}

///|
/// 上游 `sequence_match`：靠相邻字符码点差不变来识别序列（支持跳跃与非拉丁字母）。
pub fn sequence_match(password : Array[Char]) -> Array[Match] {
  let result : Array[Match] = []
  if password.length() == 1 {
    return result
  }
  let mut i = 0
  let mut last_delta : Int? = None
  let mut k = 1
  while k < password.length() {
    let delta = password[k].to_int() - password[k - 1].to_int()
    match last_delta {
      None => last_delta = Some(delta)
      Some(ld) =>
        if delta != ld {
          let j = k - 1
          push_sequence_if_valid(result, password, i, j, ld)
          i = j
          last_delta = Some(delta)
        }
    }
    k += 1
  }
  match last_delta {
    Some(ld) =>
      push_sequence_if_valid(result, password, i, password.length() - 1, ld)
    None => ()
  }
  result
}

// ---------------------------------------------------------------------------
// 正则匹配
// ---------------------------------------------------------------------------

///|
/// 上游 `REGEXEN.recent_year` 用的是 `/19\d\d|200\d|201\d/g`（2017 年的数据）。
/// zxcvbn-rs 已把它更新为 `/19\d\d|20\d\d/`，本项目沿用更新后的范围，
/// 否则 2020 年之后的年份识别不出来。
fn is_recent_year_at(password : Array[Char], i : Int) -> Bool {
  if i + 3 >= password.length() {
    return false
  }
  let c0 = password[i]
  let c1 = password[i + 1]
  let ok_prefix = (c0 == '1' && c1 == '9') || (c0 == '2' && c1 == '0')
  if !ok_prefix {
    return false
  }
  is_digit(password[i + 2]) && is_digit(password[i + 3])
}

///|
/// 上游 `regex_match`。这里不用 Regex，直接手写等价扫描——
/// 一是 core 的正则不支持 `\d`，二是需要在 char 数组（标量值）下标上定位。
pub fn regex_match(password : Array[Char]) -> Array[Match] {
  let matches : Array[Match] = []
  let len = password.length()
  let mut i = 0
  // 与上游 g 标志语义一致：找到后跳到匹配末尾，非重叠
  while i + 4 <= len {
    if is_recent_year_at(password, i) {
      matches.push(
        Match::Regex({
          i,
          j: i + 3,
          token: slice_to_string(password, i, i + 3),
          regex_name: "recent_year",
          guesses: 0.0,
          guesses_log10: 0.0,
        }),
      )
      i += 4
    } else {
      i += 1
    }
  }
  sort_matches(matches)
}

// ---------------------------------------------------------------------------
// 日期匹配
// ---------------------------------------------------------------------------

///|
/// 上游 `date_max_year`。
let date_max_year = 2050

///|
/// 上游 `date_min_year`。
let date_min_year = 1000

///|
/// 上游 `date_splits`：无分隔符日期按长度切分的 (k, l) 组合。
let date_splits : Map[Int, Array[(Int, Int)]] = Map([
  (4, [(1, 2), (2, 3)]),
  (5, [(1, 3), (2, 3)]),
  (6, [(1, 2), (2, 4), (4, 5)]),
  (7, [(1, 3), (2, 3), (4, 5), (4, 6)]),
  (8, [(2, 4), (4, 6)]),
])

///|
/// 上游 `date_match` 的无分隔符分支用的 `maybe_date_no_separator`。
fn is_maybe_date_no_separator(token : Array[Char]) -> Bool {
  let len = token.length()
  if len < 4 || len > 8 {
    return false
  }
  all_ascii_digit(token)
}

///|
/// 上游 `maybe_date_with_separator` 的手写等价实现。
/// 返回 `(第一段, 分隔符, 第二段, 第三段)`。
///
/// 上游正则 `^(\d{1,4})([\s/\\_.-])(\d{1,2})\2(\d{1,4})$` 是贪婪匹配，
/// 因此按"段长从大到小"试探，首个成功者即正则语义下的选择。
fn parse_maybe_date_with_separator(
  token : Array[Char],
) -> (Int, Char, Int, Int)? {
  let len = token.length()
  let mut l1 = if len < 4 { len } else { 4 }
  while l1 >= 1 {
    if !all_ascii_digit(view_to_array(token[0:l1])) {
      l1 -= 1
      continue
    }
    let sep_index = l1
    if sep_index >= len {
      l1 -= 1
      continue
    }
    let sep = token[sep_index]
    if !is_date_separator(sep) {
      l1 -= 1
      continue
    }
    let mut l2 = if len - sep_index - 1 < 2 { len - sep_index - 1 } else { 2 }
    while l2 >= 1 {
      let d2_start = sep_index + 1
      let d2_end = d2_start + l2
      if d2_end > len {
        l2 -= 1
        continue
      }
      if !all_ascii_digit(view_to_array(token[d2_start:d2_end])) {
        l2 -= 1
        continue
      }
      let second_sep = d2_end
      if second_sep >= len || token[second_sep] != sep {
        l2 -= 1
        continue
      }
      let d3_start = second_sep + 1
      if d3_start >= len {
        l2 -= 1
        continue
      }
      let d3_len = len - d3_start
      if d3_len < 1 ||
        d3_len > 4 ||
        !all_ascii_digit(view_to_array(token[d3_start:len])) {
        l2 -= 1
        continue
      }
      let d1 = digits_to_int(view_to_array(token[0:l1]))
      let d2 = digits_to_int(view_to_array(token[d2_start:d2_end]))
      let d3 = digits_to_int(view_to_array(token[d3_start:len]))
      return Some((d1, sep, d2, d3))
    }
    l1 -= 1
  }
  None
}

///|
/// 上游 `[\s/\\_.-]` 的字符集。JS 的 `\s` 覆盖多种 Unicode 空白，这里用
/// MoonBit 的 `Char::is_whitespace` 对齐。
fn is_date_separator(c : Char) -> Bool {
  c == '/' || c == '\\' || c == '_' || c == '.' || c == '-' || c.is_whitespace()
}

///|
/// 把纯数字字符数组转成整数（对应上游 `parseInt`）。
fn digits_to_int(chars : Array[Char]) -> Int {
  let mut value = 0
  for c in chars {
    if !is_digit(c) {
      // 上游 parseInt 会解析到第一个非数字字符为止；调用点保证全是数字
      break
    }
    value = value * 10 + (c.to_int() - '0'.to_int())
  }
  value
}

///|
/// 上游 `map_ints_to_dm`：尝试把两个整数映射为 (day, month)，两种顺序都试。
fn map_ints_to_dm(ints : (Int, Int)) -> (Int, Int)? {
  let (a, b) = ints
  // [ints, reversed(ints)]
  if a >= 1 && a <= 31 && b >= 1 && b <= 12 {
    return Some((a, b))
  }
  if b >= 1 && b <= 31 && a >= 1 && a <= 12 {
    return Some((b, a))
  }
  None
}

///|
/// 上游 `map_ints_to_dmy`：返回 `(year, month, day)`。
fn map_ints_to_dmy(ints : (Int, Int, Int)) -> (Int, Int, Int)? {
  let (n0, n1, n2) = ints
  // 中间整数是月的候选：绝不能超过 31，也不能为 0
  if n1 > 31 || n1 <= 0 {
    return None
  }
  let mut over_12 = 0
  let mut over_31 = 0
  let mut under_1 = 0
  for n in [n0, n1, n2] {
    if (n > 99 && n < date_min_year) || n > date_max_year {
      return None
    }
    if n > 31 {
      over_31 += 1
    }
    if n > 12 {
      over_12 += 1
    }
    if n <= 0 {
      under_1 += 1
    }
  }
  if over_31 >= 2 || over_12 == 3 || under_1 >= 2 {
    return None
  }
  // 先找四位年：yyyy + daymonth，或 daymonth + yyyy
  let year_splits : Array[(Int, (Int, Int))] = [(n2, (n0, n1)), (n0, (n1, n2))]
  for split in year_splits {
    let (y, rest) = split
    if date_min_year <= y && y <= date_max_year {
      // 候选里含四位年但剩余部分凑不出日/月 => 不是日期，直接否定
      match map_ints_to_dm(rest) {
        Some(dm) => return Some((y, dm.1, dm.0))
        None => return None
      }
    }
  }
  // 没有四位年时，两位年最灵活
  for split in year_splits {
    let (y, rest) = split
    match map_ints_to_dm(rest) {
      Some(dm) => return Some((two_to_four_digit_year(y), dm.1, dm.0))
      None => ()
    }
  }
  None
}

///|
/// 上游 `two_to_four_digit_year`。
fn two_to_four_digit_year(year : Int) -> Int {
  if year > 99 {
    year
  } else if year > 50 {
    // 87 -> 1987
    year + 1900
  } else {
    // 15 -> 2015
    year + 2000
  }
}

///|
/// 上游 `date_match`。
pub fn date_match(password : Array[Char], reference_year : Int) -> Array[Match] {
  let matches : Array[Match] = []
  let len = password.length()
  // --- 无分隔符：长度 4..8 ---
  if len >= 4 {
    let mut i = 0
    while i <= len - 4 {
      let mut j = i + 3
      while j <= i + 7 {
        if j >= len {
          j += 1
          continue
        }
        let token = view_to_array(password[i:j + 1])
        if is_maybe_date_no_separator(token) {
          let candidates : Array[(Int, Int, Int)] = []
          let splits = match date_splits.get(token.length()) {
            Some(v) => v
            None => []
          }
          for split in splits {
            let (k, l) = split
            let d1 = digits_to_int(view_to_array(token[0:k]))
            let d2 = digits_to_int(view_to_array(token[k:l]))
            let d3 = digits_to_int(view_to_array(token[l:token.length()]))
            match map_ints_to_dmy((d1, d2, d3)) {
              Some(dmy) => candidates.push(dmy)
              None => ()
            }
          }
          if candidates.length() > 0 {
            // 同一子串可能有多种 dmy 解释，取"离参考年最近"的那个
            let mut best = candidates[0]
            let mut best_distance = abs_int(best.0 - reference_year)
            for candidate in candidates[1:] {
              let distance = abs_int(candidate.0 - reference_year)
              if distance < best_distance {
                best = candidate
                best_distance = distance
              }
            }
            matches.push(
              Match::Date({
                i,
                j,
                token: slice_to_string(password, i, j),
                separator: "",
                year: best.0,
                month: best.1,
                day: best.2,
                guesses: 0.0,
                guesses_log10: 0.0,
              }),
            )
          }
        }
        j += 1
      }
      i += 1
    }
  }
  // --- 带分隔符：长度 6..10 ---
  if len >= 6 {
    let mut i = 0
    while i <= len - 6 {
      let mut j = i + 5
      while j <= i + 9 {
        if j >= len {
          j += 1
          continue
        }
        let token = view_to_array(password[i:j + 1])
        match parse_maybe_date_with_separator(token) {
          Some((d1, sep, d2, d3)) =>
            match map_ints_to_dmy((d1, d2, d3)) {
              Some(dmy) =>
                matches.push(
                  Match::Date({
                    i,
                    j,
                    token: slice_to_string(password, i, j),
                    separator: sep.to_string(),
                    year: dmy.0,
                    month: dmy.1,
                    day: dmy.2,
                    guesses: 0.0,
                    guesses_log10: 0.0,
                  }),
                )
              None => ()
            }
          None => ()
        }
        j += 1
      }
      i += 1
    }
  }
  // 去掉"是别的日期匹配子串"的噪声项
  let filtered : Array[Match] = []
  let mut idx = 0
  while idx < matches.length() {
    let m = matches[idx]
    let mut is_submatch = false
    let mut other_idx = 0
    while other_idx < matches.length() {
      if other_idx != idx {
        let other = matches[other_idx]
        if other.start_index() <= m.start_index() &&
          other.end_index() >= m.end_index() {
          is_submatch = true
          other_idx = matches.length()
          break
        }
      }
      other_idx += 1
    }
    if !is_submatch {
      filtered.push(m)
    }
    idx += 1
  }
  sort_matches(filtered)
}
