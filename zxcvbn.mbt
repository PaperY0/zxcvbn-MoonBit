// 公共 API 收口：`zxcvbn()` 入口与结果类型。
//
// 移植来源：dropbox/zxcvbn `src/main.coffee` + `time_estimates.coffee` + `feedback.coffee`
// （MIT, (c) Dropbox, Inc.）
//
// 匹配/评分的实现分别在 matching.mbt / scoring.mbt；这里只做编排。

///|
/// 四类破解场景的耗时（秒）。
///
/// 对应上游的四档攻击模型：在线限流（100 次/小时）、在线不限流（10 次/秒）、
/// 离线慢哈希（1e4 次/秒）、离线快哈希（1e10 次/秒）。
pub struct CrackTimes {
  online_throttling_100_per_hour : Double
  online_no_throttling_10_per_second : Double
  offline_slow_hashing_1e4_per_second : Double
  offline_fast_hashing_1e10_per_second : Double
} derive(Eq, Debug)

///|
pub extend CrackTimes with Eq::{equal, not_equal}

///|
pub extend CrackTimes with @debug.Debug::{to_repr}

///|
/// 可执行的改进建议（与上游 feedback 对齐）。
pub struct Feedback {
  warning : String
  suggestions : Array[String]
} derive(Eq, Debug)

///|
pub extend Feedback with Eq::{equal, not_equal}

///|
pub extend Feedback with @debug.Debug::{to_repr}

///|
/// zxcvbn 评估结果。
///
/// `guesses` / `guesses_log10` / `score` 是保守的**攻击模型下限**估计：
/// zxcvbn 不是"字符类别计数"，而是做完全模式匹配后取最小猜测数。
pub struct Entropy {
  password : String
  /// 保守估计的猜测次数
  guesses : Double
  /// log10(guesses)
  guesses_log10 : Double
  /// 0..4：阈值 1e3 / 1e6 / 1e8 / 1e10（与上游一致）
  score : Int
  /// 四场景破解秒数
  crack_times_seconds : CrackTimes
  /// 人类可读破解时间
  crack_times_display : CrackTimesDisplay
  /// 取最小 guesses 的最优非重叠匹配序列
  sequence : Array[Match]
  feedback : Feedback
} derive(Eq, Debug)

///|
pub extend Entropy with Eq::{equal, not_equal}

///|
pub extend Entropy with @debug.Debug::{to_repr}

///|
/// 上游 `feedback.default_feedback`：没有任何可用建议时的兜底。
pub let default_feedback : Feedback = {
  warning: "",
  suggestions: [
    "Use a few words, avoid common phrases", "No need for symbols, digits, or uppercase letters",
  ],
}

///|
/// 评估一个密码的强度。
///
/// - `user_inputs`：与用户相关的词（用户名/邮箱等），命中时显著降低强度估计；
/// - `reference_year`：日期匹配的参考年份。上游取运行时当年，MoonBit core 没有
///   时钟 API，故参数化并默认 2026，同时让测试完全确定。
///
/// 移植来源：dropbox/zxcvbn（MIT）。
pub fn zxcvbn(
  password : String,
  user_inputs : Array[String],
  reference_year? : Int = 2026,
) -> Entropy {
  // 上游用模块级全局变量 `set_user_input_dictionary` 传递用户输入，
  // 每次调用都要重置以保持无状态；这里改为调用时传入，天然纯函数、可重入。
  let sanitized = sanitize_user_inputs(user_inputs)
  let user_dict = build_ranked_dict(sanitized)
  let matcher = Omnimatcher::new(user_dict, reference_year)
  let matches = matcher.run(password)
  let result = most_guessable_match_sequence(password, matches, reference_year)
  let attack = estimate_attack_times(result.guesses)
  let feedback = get_feedback(attack.score, result.sequence)
  {
    password,
    guesses: result.guesses,
    guesses_log10: result.guesses_log10,
    score: attack.score,
    crack_times_seconds: attack.crack_times_seconds,
    crack_times_display: attack.crack_times_display,
    sequence: result.sequence,
    feedback,
  }
}

///|
/// 上游 `main.coffee` 的 `sanitized_inputs`：只接受字符串（MoonBit 侧本来就是
/// `Array[String]`）并统一小写化。
fn sanitize_user_inputs(user_inputs : Array[String]) -> Array[String] {
  user_inputs.map(input => input.to_lower())
}

///|
/// 便捷入口：不带用户输入、用默认参考年。
pub fn zxcvbn_password(password : String) -> Entropy {
  zxcvbn(password, [])
}
