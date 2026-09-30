// 时间估算：四场景破解时间、人类可读格式、0–4 强度分。
//
// 移植来源：dropbox/zxcvbn `src/time_estimates.coffee`（MIT, (c) Dropbox, Inc.）

///|
/// 四类破解场景的耗时（秒）。类型定义放在 zxcvbn.mbt（公共 API）。

///|
/// 上游 `time_estimates.estimate_attack_times` 的完整返回。
/// 注意 `crack_times_display` 是人类可读字符串，与秒数结构分开。
pub struct AttackTimes {
  crack_times_seconds : CrackTimes
  crack_times_display : CrackTimesDisplay
  score : Int
} derive(Eq, Debug)

///|
pub extend AttackTimes with Eq::{equal, not_equal}

///|
pub extend AttackTimes with @debug.Debug::{to_repr}

///|
/// 四类破解场景的人类可读耗时。
pub struct CrackTimesDisplay {
  online_throttling_100_per_hour : String
  online_no_throttling_10_per_second : String
  offline_slow_hashing_1e4_per_second : String
  offline_fast_hashing_1e10_per_second : String
} derive(Eq, Debug)

///|
pub extend CrackTimesDisplay with Eq::{equal, not_equal}

///|
pub extend CrackTimesDisplay with @debug.Debug::{to_repr}

///|
/// 上游 `estimate_attack_times`。
pub fn estimate_attack_times(guesses : Double) -> AttackTimes {
  // 上游是在线限流场景下每秒 100/3600 次；这里保持同一算式。
  let seconds : CrackTimes = {
    online_throttling_100_per_hour: guesses / (100.0 / 3600.0),
    online_no_throttling_10_per_second: guesses / 10.0,
    offline_slow_hashing_1e4_per_second: guesses / 1.0e4,
    offline_fast_hashing_1e10_per_second: guesses / 1.0e10,
  }
  let display : CrackTimesDisplay = {
    online_throttling_100_per_hour: display_time(
      seconds.online_throttling_100_per_hour,
    ),
    online_no_throttling_10_per_second: display_time(
      seconds.online_no_throttling_10_per_second,
    ),
    offline_slow_hashing_1e4_per_second: display_time(
      seconds.offline_slow_hashing_1e4_per_second,
    ),
    offline_fast_hashing_1e10_per_second: display_time(
      seconds.offline_fast_hashing_1e10_per_second,
    ),
  }
  {
    crack_times_seconds: seconds,
    crack_times_display: display,
    score: guesses_to_score(guesses),
  }
}

///|
/// 上游 `guesses_to_score`：DELTA=5 的阈值分档。
///
/// 分档含义（原上游注释）：
/// * 0 `too guessable`：从在线限流攻击下也不安全
/// * 1 `very guessable`：能防住在线限流攻击
/// * 2 `somewhat guessable`：能防住不限流在线攻击
/// * 3 `safely unguessable`：能防住离线慢哈希攻击（bcrypt/scrypt/PBKDF2/argon）
/// * 4 `very unguessable`：同场景下更强的保护
pub fn guesses_to_score(guesses : Double) -> Int {
  let delta = 5.0
  if guesses < 1.0e3 + delta {
    0
  } else if guesses < 1.0e6 + delta {
    1
  } else if guesses < 1.0e8 + delta {
    2
  } else if guesses < 1.0e10 + delta {
    3
  } else {
    4
  }
}

///|
/// 上游 `display_time`。
///
/// 注意上游的算式是 `Math.round(seconds) / minute` 而不是 `Math.round(seconds/minute)`，
/// 于是会产出 `1.5 minutes` 这样的分数形式——本项目如实保留以对齐官方向量。
fn display_time(seconds : Double) -> String {
  let minute = 60.0
  let hour = minute * 60.0
  let day = hour * 24.0
  let month = day * 31.0
  let year = month * 12.0
  let century = year * 100.0
  let (text, display_num) = if seconds < 1.0 {
    ("less than a second", -1.0)
  } else if seconds < minute {
    let base = @math.round(seconds)
    ("\{base} second", base)
  } else if seconds < hour {
    let base = @math.round(seconds) / minute
    ("\{base} minute", base)
  } else if seconds < day {
    let base = @math.round(seconds) / hour
    ("\{base} hour", base)
  } else if seconds < month {
    let base = @math.round(seconds) / day
    ("\{base} day", base)
  } else if seconds < year {
    let base = @math.round(seconds) / month
    ("\{base} month", base)
  } else if seconds < century {
    let base = @math.round(seconds) / year
    ("\{base} year", base)
  } else {
    ("centuries", -1.0)
  }
  // -1 表示"没有数量"（less than a second / centuries），不加复数后缀
  if display_num >= 0.0 && display_num != 1.0 {
    text + "s"
  } else {
    text
  }
}
