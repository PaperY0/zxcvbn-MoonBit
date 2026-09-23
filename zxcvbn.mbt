// PaperY0/zxcvbn —— Dropbox zxcvbn 的 MoonBit 移植（MIT，(c) Dropbox, Inc.）
//
// 本文件是公共 API 的设计契约（Phase 2 收口时实现）。
// 完整选题说明与实现步骤：docs/implementation-plan.md

///|
/// 模式类型。命名与上游 pattern 字符串一致，便于与官方向量/差分结果对照。
pub enum Pattern {
  Dictionary
  Spatial
  Repeat
  Sequence
  Regex
  Date
  BruteForce
} derive(Eq, Debug)

///|
/// 一次模式匹配。[i, j] 为闭区间字符下标（按 Unicode 标量值，非 UTF-16 码元）。
pub struct Match {
  i : Int
  j : Int
  token : String
  pattern : Pattern
  guesses : Int
} derive(Eq, Debug)

///|
/// 四类破解场景的耗时（秒）。
pub struct CrackTimes {
  online_throttling_100_per_hour : Double
  online_no_throttling_10_per_second : Double
  offline_slow_hashing_1e4_per_second : Double
  offline_fast_hashing_1e10_per_second : Double
} derive(Eq, Debug)

///|
/// 可执行的改进建议（与上游 feedback 对齐）。
pub struct Feedback {
  warning : String
  suggestions : Array[String]
} derive(Eq, Debug)

///|
/// zxcvbn 评估结果。
pub struct Entropy {
  /// 保守估计的猜测次数（攻击模型下限）
  guesses : Int
  /// log10(guesses)
  guesses_log10 : Double
  /// 0..4：阈值 1e3 / 1e6 / 1e8 / 1e10（与上游一致）
  score : Int
  /// 四场景破解秒数
  crack_times_seconds : CrackTimes
  /// 人类可读破解时间
  crack_times_display : CrackTimes
  /// 取最小 guesses 的最优非重叠匹配序列
  sequence : Array[Match]
  feedback : Feedback
} derive(Eq, Debug)

///|
/// 评估一个密码的强度。
///
/// - `user_inputs`：与用户相关的词（用户名/邮箱等），命中时显著降低强度估计；
/// - `reference_year`：日期匹配的参考年份（上游取运行时当年；MoonBit core 无时钟，
///   故参数化，默认 2026，同时保证测试确定性）。
///
/// 移植来源：dropbox/zxcvbn（MIT）。
pub fn zxcvbn(
  password : String,
  user_inputs : Array[String],
  reference_year? : Int = 2026,
) -> Entropy {
  abort(
    "zxcvbn engine not implemented yet (Phase 1–2); got password len=\{password.length()}, user_inputs=\{user_inputs.length()}, reference_year=\{reference_year}; see docs/implementation-plan.md",
  )
}
