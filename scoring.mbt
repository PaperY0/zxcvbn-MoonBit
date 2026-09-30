// 评分：数学底座 + 最优匹配序列 DP + 每模式猜测数估计。
//
// 移植来源：dropbox/zxcvbn `src/scoring.coffee`（MIT, (c) Dropbox, Inc.）
//
// 关键点：上游的 guesses 全程是 JS 浮点数。本项目沿用 Double 语义——
// 长密码的 bruteforce guesses 会达到 10^n 乃至 Infinity，用 Int 会静默溢出，
// 而 `guesses_log10` 与破解时间只需要浮点精度。这也与 zxcvbn-rs 用 f64 一致。
// （公共 API 从早期草案的 Int 改为 Double，README 已同步说明。）

///|
/// 上游 `scoring.nCk`：组合数，官方向量 `nCk(33,7) = 4272048`。
pub fn nCk(n : Int, k : Int) -> Double {
  if k > n {
    return 0.0
  }
  if k == 0 {
    return 1.0
  }
  let mut n_ = n
  let mut r = 1.0
  let mut d = 1
  while d <= k {
    r = r * n_.to_double()
    r = r / d.to_double()
    n_ -= 1
    d += 1
  }
  r
}

///|
/// 上游 `scoring.log10`：`Math.log(n) / Math.log(10)`。
pub fn log10(n : Double) -> Double {
  @math.log10(n)
}

///|
/// 上游 `scoring.log2`：`Math.log(n) / Math.log(2)`。
pub fn log2(n : Double) -> Double {
  @math.log2(n)
}

///|
/// 上游 `scoring.factorial`。
pub fn factorial(n : Int) -> Double {
  if n < 2 {
    return 1.0
  }
  let mut f = 1.0
  let mut i = 2
  while i <= n {
    f = f * i.to_double()
    i += 1
  }
  f
}

///|
/// 上游 `bruteforce_cardinality`。
let bruteforce_cardinality : Double = 10.0

///|
/// 上游 `min_guesses_before_growing_sequence`：DP 里长度惩罚项的底数。
let min_guesses_before_growing_sequence : Double = 10000.0

///|
/// 上游 `min_submatch_guesses_single_char`。
let min_submatch_guesses_single_char : Double = 10.0

///|
/// 上游 `min_submatch_guesses_multi_char`。
let min_submatch_guesses_multi_char : Double = 50.0

///|
/// 上游 `min_year_space`。
let min_year_space : Double = 20.0

///|
/// 上游 JS 的 `Number.MAX_VALUE`（1.7976931348623157e308）。
/// bruteforce guesses 在长度 >309 时会上溢到 Infinity，此时回落到该值。
let max_double : Double = 1.7976931348623157e308

///|
/// 上游 `most_guessable_match_sequence` 的结果。
pub struct MatchSequence {
  password : String
  guesses : Double
  guesses_log10 : Double
  sequence : Array[Match]
} derive(Eq, Debug)

///|
pub extend MatchSequence with Eq::{equal, not_equal}

///|
pub extend MatchSequence with @debug.Debug::{to_repr}

// ---------------------------------------------------------------------------
// 最优匹配序列 DP
// ---------------------------------------------------------------------------

///|
/// 上游 `scoring.most_guessable_match_sequence`。
///
/// 把一组可能重叠的匹配，转换为**非重叠**且 guesses 最小的序列。
/// 目标函数（与上游一致）：
///
/// ```text
/// g = l! * Prod(m.guesses for m in sequence) + D^(l - 1)
/// ```
///
/// 其中 `l` 为序列长度，`l!` 是 l 个模式的排列数，`D^(l-1)` 是长度惩罚
/// （攻击者会先试更短的序列）。
///
/// `exclude_additive` 仅供上游测试使用（测试里会把加性惩罚关掉）。
pub fn most_guessable_match_sequence(
  password : String,
  matches : Array[Match],
  reference_year : Int,
  exclude_additive? : Bool = false,
) -> MatchSequence {
  let chars = password.to_array()
  let n = chars.length()
  // 角落：空密码
  if n == 0 {
    return { password, guesses: 1.0, guesses_log10: 0.0, sequence: [], }
  }
  // 按结束下标 j 分区；为了确定性，每个分区按 i 排序
  let matches_by_j : Array[Array[Match]] = Array::makei(n, _ => [])
  for m in matches {
    let k = m.end_index()
    if k < n {
      matches_by_j[k].push(m)
    }
  }
  for lst in matches_by_j {
    lst.sort_by((a, b) => a.start_index() - b.start_index())
  }
  // optimal.m[k][l]：覆盖密码 [0..k] 前缀的最优长度-l 序列的最后一个匹配
  let optimal_m : Array[Map[Int, Match]] = Array::makei(n, _ => Map([]))
  // optimal.pi[k][l]：上述序列的 guesses 乘积项
  let optimal_pi : Array[Map[Int, Double]] = Array::makei(n, _ => Map([]))
  // optimal.g[k][l]：上述序列的整体度量
  let optimal_g : Array[Map[Int, Double]] = Array::makei(n, _ => Map([]))

  // --- helper: 考虑"以 m 结尾的长度-l 序列"是否更优 -------------
  let update : (Match, Int) -> Unit = (m, l) => {
    let k = m.end_index()
    let mut pi = estimate_guesses(m, chars.length(), reference_year)
    if l > 1 {
      // l-1 序列必须结束在 m.i - 1 上
      pi = pi * optimal_pi[m.start_index() - 1][l - 1]
    }
    let mut g = factorial(l) * pi
    if !exclude_additive {
      g = g +
        @math.pow(min_guesses_before_growing_sequence, (l - 1).to_double())
    }
    // 若同 k 上已有 l' <= l 且 g' <= g 的序列，本序列无价值
    let pairs : Array[(Int, Double)] = Array::from_iter(optimal_g[k].iter())
    let mut skip = false
    let mut idx = 0
    while idx < pairs.length() && !skip {
      let (competing_l, competing_g) = pairs[idx]
      if competing_l <= l && competing_g <= g {
        skip = true
      }
      idx += 1
    }
    if !skip {
      optimal_g[k][l] = g
      optimal_m[k][l] = m
      optimal_pi[k][l] = pi
    }
  }

  // --- helper: 构造覆盖 [i, j] 的 bruteforce 匹配 -----------------
  let make_bruteforce_match : (Int, Int) -> Match = (i, j) => {
    Match::Bruteforce({
      i,
      j,
      token: String::from_array(chars[i:j + 1]),
      guesses: 0.0,
      guesses_log10: 0.0,
    })
  }

  // --- helper: 评估以 k 结尾的 bruteforce 匹配 -------------------
  let bruteforce_update : (Int) -> Unit = k => {
    // 单个 bruteforce 匹配覆盖整个 [0, k] 前缀
    update(make_bruteforce_match(0, k), 1)
    let mut i = 1
    while i <= k {
      let m = make_bruteforce_match(i, k)
      // 尝试把它接到 optimal[i-1] 的各序列后面
      let pairs : Array[(Int, Match)] = Array::from_iter(
        optimal_m[i - 1].iter(),
      )
      for pair in pairs {
        let (l, last_m) = pair
        // 角落：最优序列不会出现两个相邻的 bruteforce 匹配——单个覆盖同一区间的
        // bruteforce 猜测数更少、长度更短，严格更优，所以这些情况可以跳过。
        if last_m.pattern() != "bruteforce" {
          update(m, l + 1)
        }
      }
      i += 1
    }
  }

  // --- helper: 从终点回溯构造最终序列 ---------------------------
  let unwind : (Int) -> Array[Match] = end => {
    let seq : Array[Match] = []
    let mut k = end - 1
    // 取整体 g 最小的长度 l。打平时 JS 对象整数键按升序遍历，
    // 于是取到较小的 l；这里显式排序以复现该行为。
    let keys : Array[Int] = Array::from_iter(optimal_g[k].keys())
    keys.sort()
    let mut l = -1
    let mut best_g = 0.0
    let mut first = true
    for key in keys {
      let g = optimal_g[k][key]
      if first || g < best_g {
        l = key
        best_g = g
        first = false
      }
    }
    while k >= 0 && l > 0 {
      match optimal_m[k].get(l) {
        Some(m) => {
          seq.push(m)
          k = m.start_index() - 1
          l -= 1
        }
        // 正常不可达；防御性跳出避免越界
        None => k = -1
      }
    }
    seq.rev_in_place()
    seq
  }

  let mut k = 0
  while k < n {
    for m in matches_by_j[k] {
      if m.start_index() > 0 {
        let pairs : Array[(Int, Match)] = Array::from_iter(
          optimal_m[m.start_index() - 1].iter(),
        )
        for pair in pairs {
          let (l, _last_m) = pair
          update(m, l + 1)
        }
      } else {
        update(m, 1)
      }
    }
    bruteforce_update(k)
    k += 1
  }
  let sequence = unwind(n)
  let optimal_l = sequence.length()
  let guesses = optimal_g[n - 1][optimal_l]
  { password, guesses, guesses_log10: log10(guesses), sequence, }
}

// ---------------------------------------------------------------------------
// 猜测数估计
// ---------------------------------------------------------------------------

///|
/// 上游 `scoring.estimate_guesses`：按模式分派并缓存。
///
/// `password_length` 是密码的**标量值**长度（上游用 UTF-16 码元长度，
/// 这是本项目有意保留的差异，见 README）。
fn estimate_guesses(
  m : Match,
  password_length : Int,
  reference_year : Int,
) -> Double {
  // 匹配的猜测数不会变，缓存之
  if m.guesses() != 0.0 {
    return m.guesses()
  }
  let mut min_guesses = 1.0
  let span = m.span_length()
  if span < password_length {
    min_guesses = if span == 1 {
      min_submatch_guesses_single_char
    } else {
      min_submatch_guesses_multi_char
    }
  }
  let guesses = match m {
    Bruteforce(bm) => bruteforce_guesses(bm)
    Dictionary(dm) => dictionary_guesses(dm)
    Spatial(sm) => spatial_guesses(sm)
    Repeat(rm) => repeat_guesses(rm)
    Sequence(sm) => sequence_guesses(sm)
    Regex(rm) => regex_guesses(rm, reference_year)
    Date(dm) => date_guesses(dm, reference_year)
  }
  let result = if guesses > min_guesses { guesses } else { min_guesses }
  m.set_guesses(result)
  m.set_guesses_log10(log10(result))
  result
}

///|
/// 上游 `bruteforce_guesses`。
fn bruteforce_guesses(m : BruteforceMatch) -> Double {
  let len = m.token.to_array().length()
  let raw = @math.pow(bruteforce_cardinality, len.to_double())
  // 上溢时回落到 JS 的 Number.MAX_VALUE
  let guesses = if raw > max_double { max_double } else { raw }
  // 小细节：让 bruteforce 猜测数至少比最小的 submatch 猜测数大 1，
  // 这样同一区间上的非 bruteforce submatch 优先
  let min_guesses = if len == 1 {
    min_submatch_guesses_single_char + 1.0
  } else {
    min_submatch_guesses_multi_char + 1.0
  }
  if guesses > min_guesses {
    guesses
  } else {
    min_guesses
  }
}

///|
/// 上游 `repeat_guesses`。
fn repeat_guesses(m : RepeatMatch) -> Double {
  m.base_guesses * m.repeat_count.to_double()
}

///|
/// 上游 `sequence_guesses`。
fn sequence_guesses(m : SequenceMatch) -> Double {
  let first_chr = m.token.to_array()[0]
  let obvious_start = first_chr == 'a' ||
    first_chr == 'A' ||
    first_chr == 'z' ||
    first_chr == 'Z' ||
    first_chr == '0' ||
    first_chr == '1' ||
    first_chr == '9'
  let mut base_guesses = if obvious_start {
    // 明显的起始点猜得更少
    4.0
  } else if is_digit(first_chr) {
    10.0
  } else {
    // 大写序列本可以给更高 base；对大小写都给 26 更保守
    26.0
  }
  if !m.ascending {
    // 除了每个升序序列，还要试降序序列 => 2 倍猜测数
    base_guesses = base_guesses * 2.0
  }
  base_guesses * m.token.to_array().length().to_double()
}

///|
/// 上游 `regex_guesses` 的 `recent_year` 分支。
fn regex_guesses(m : RegexMatch, reference_year : Int) -> Double {
  let year = digits_to_int(m.token.to_array())
  let year_space = abs_int(year - reference_year).to_double()
  if year_space > min_year_space {
    year_space
  } else {
    min_year_space
  }
}

///|
/// 上游 `date_guesses`。
fn date_guesses(m : DateMatch, reference_year : Int) -> Double {
  // base guesses = （离参考年的距离） × 一年天数
  let year_space = abs_int(m.year - reference_year).to_double()
  let clamped = if year_space > min_year_space {
    year_space
  } else {
    min_year_space
  }
  let mut guesses = clamped * 365.0
  // 分隔符选择再乘 4（约 4 种选择）
  if m.separator != "" {
    guesses = guesses * 4.0
  }
  guesses
}

///|
/// 上游 `spatial_guesses`。
fn spatial_guesses(m : SpatialMatch) -> Double {
  let (s, d) = if m.graph == "qwerty" || m.graph == "dvorak" {
    (keyboard_starting_positions, keyboard_average_degree)
  } else {
    (keypad_starting_positions, keypad_average_degree)
  }
  let mut guesses = 0.0
  let l = m.token.to_array().length()
  let t = m.turns
  // 估计长度为 L、转向数不超过 t 的模式数量
  let mut i = 2
  while i <= l {
    let possible_turns = if t < i - 1 { t } else { i - 1 }
    let mut j = 1
    while j <= possible_turns {
      guesses = guesses +
        nCk(i - 1, j - 1) * s.to_double() * @math.pow(d, j.to_double())
      j += 1
    }
    i += 1
  }
  // 移位键的额外猜测（% 代替 5、A 代替 a），与 l33t 替换的数学同构
  if m.shifted_count > 0 {
    let s_count = m.shifted_count
    let u = l - s_count
    if s_count == 0 || u == 0 {
      guesses = guesses * 2.0
    } else {
      let mut shifted_variations = 0.0
      let limit = if s_count < u { s_count } else { u }
      let mut i = 1
      while i <= limit {
        shifted_variations = shifted_variations + nCk(s_count + u, i)
        i += 1
      }
      guesses = guesses * shifted_variations
    }
  }
  guesses
}

///|
/// 上游 `dictionary_guesses`。
fn dictionary_guesses(m : DictionaryMatch) -> Double {
  let base_guesses = m.rank.to_double()
  let uppercase = uppercase_variations(m.token)
  let l33t = l33t_variations(m)
  let reversed_variations = if m.reversed { 2.0 } else { 1.0 }
  base_guesses * uppercase * l33t * reversed_variations
}

///|
/// 上游 `uppercase_variations`。
///
/// 四个上游正则：
/// * `START_UPPER = /^[A-Z][^A-Z]+$/`
/// * `END_UPPER   = /^[^A-Z]+[A-Z]$/`
/// * `ALL_UPPER   = /^[^a-z]+$/`
/// * `ALL_LOWER   = /^[^A-Z]+$/`
fn uppercase_variations(word : String) -> Double {
  let chars = word.to_array()
  // 全小写（或没有大写字母）不增加搜索空间
  if all_non_upper(chars) {
    return 1.0
  }
  if word.to_lower() == word {
    return 1.0
  }
  // 首字母大写是最常见的做法，只让搜索空间翻倍（未大写 + 首大写）；
  // 全大写和尾大写也够常见，同样低估为 2 倍
  if is_start_upper(chars) || is_end_upper(chars) || all_non_lower(chars) {
    return 2.0
  }
  // 否则计算"最多把 U 个大写字母转小写"的方案数；
  // 若大写比小写还多（如 PASSwORD），反过来算"最多把 L 个小写转大写"
  let u = count_if(chars, is_upper)
  let l = count_if(chars, is_lower)
  let mut variations = 0.0
  let limit = if u < l { u } else { l }
  let mut i = 1
  while i <= limit {
    variations = variations + nCk(u + l, i)
    i += 1
  }
  variations
}

///|
/// 上游 `ALL_LOWER`：所有字符都不是 ASCII 大写（且至少一个字符）。
fn all_non_upper(chars : Array[Char]) -> Bool {
  if chars.length() == 0 {
    return false
  }
  for c in chars {
    if is_upper(c) {
      return false
    }
  }
  true
}

///|
/// 上游 `ALL_UPPER`：所有字符都不是 ASCII 小写（且至少一个字符）。
fn all_non_lower(chars : Array[Char]) -> Bool {
  if chars.length() == 0 {
    return false
  }
  for c in chars {
    if is_lower(c) {
      return false
    }
  }
  true
}

///|
/// 上游 `START_UPPER`：首字符大写，其余都不是大写（至少 2 个字符）。
fn is_start_upper(chars : Array[Char]) -> Bool {
  if chars.length() < 2 {
    return false
  }
  if !is_upper(chars[0]) {
    return false
  }
  for c in chars[1:chars.length()] {
    if is_upper(c) {
      return false
    }
  }
  true
}

///|
/// 上游 `END_UPPER`：末字符大写，前面都不是大写（至少 2 个字符）。
fn is_end_upper(chars : Array[Char]) -> Bool {
  let n = chars.length()
  if n < 2 {
    return false
  }
  if !is_upper(chars[n - 1]) {
    return false
  }
  for c in chars[0:n - 1] {
    if is_upper(c) {
      return false
    }
  }
  true
}

///|
/// 上游 `l33t_variations`。
fn l33t_variations(m : DictionaryMatch) -> Double {
  if !m.l33t {
    return 1.0
  }
  let mut variations = 1.0
  // 先转小写再统计：大小写不该影响 l33t 计算
  let chrs = m.token.to_lower().to_array()
  for pair in m.sub {
    let (subbed, unsubbed) = pair
    let s = count_if(chrs, c => c == subbed)
    let u = count_if(chrs, c => c == unsubbed)
    if s == 0 || u == 0 {
      // 对该替换，密码要么全替换（444）要么全不替换（aaa），
      // 视为搜索空间翻倍
      variations = variations * 2.0
    } else {
      // 以 aa44a 为例：U=3, S=2，攻击者要试"不替换 + 替 1 个 + 替 2 个"
      let limit = if u < s { u } else { s }
      let mut possibilities = 0.0
      let mut i = 1
      while i <= limit {
        possibilities = possibilities + nCk(u + s, i)
        i += 1
      }
      variations = variations * possibilities
    }
  }
  variations
}

///|
/// 统计满足谓词的字符个数。
fn count_if(chars : Array[Char], pred : (Char) -> Bool) -> Int {
  let mut n = 0
  for c in chars {
    if pred(c) {
      n += 1
    }
  }
  n
}
