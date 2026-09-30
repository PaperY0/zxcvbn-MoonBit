// time_estimates.mbt 的黑盒测试。
//
// 上游没有为 time_estimates 单独写 test 块，这里按其公式补齐：
// display_time 的分档逻辑（上游实际编译为 `Math.round(seconds / minute)`，
// 先除后圆整、结果为整数）与 guesses_to_score 的 1e3/1e6/1e8/1e10 + DELTA=5 阈值。

///|
test "guesses_to_score thresholds (1e3/1e6/1e8/1e10 + DELTA 5)" {
  inspect(@zxcvbn.guesses_to_score(0.0), content="0")
  inspect(@zxcvbn.guesses_to_score(1.0), content="0")
  inspect(@zxcvbn.guesses_to_score(1000.0), content="0")
  inspect(@zxcvbn.guesses_to_score(1004.0), content="0")
  inspect(@zxcvbn.guesses_to_score(1005.0), content="1")
  inspect(@zxcvbn.guesses_to_score(1000000.0), content="1")
  inspect(@zxcvbn.guesses_to_score(1000004.0), content="1")
  inspect(@zxcvbn.guesses_to_score(1000005.0), content="2")
  inspect(@zxcvbn.guesses_to_score(100000000.0), content="2")
  inspect(@zxcvbn.guesses_to_score(100000004.0), content="2")
  inspect(@zxcvbn.guesses_to_score(100000005.0), content="3")
  inspect(@zxcvbn.guesses_to_score(10000000000.0), content="3")
  inspect(@zxcvbn.guesses_to_score(10000000004.0), content="3")
  inspect(@zxcvbn.guesses_to_score(10000000005.0), content="4")
  inspect(@zxcvbn.guesses_to_score(1.0e100), content="4")
}

///|
/// 四场景算式：在线限流（100/h）、在线不限流（10/s）、
/// 离线慢哈希（1e4/s）、离线快哈希（1e10/s）。
test "estimate_attack_times computes all four scenarios" {
  let t = @zxcvbn.estimate_attack_times(1000.0)
  inspect(t.crack_times_seconds.online_throttling_100_per_hour, content="36000")
  inspect(
    t.crack_times_seconds.online_no_throttling_10_per_second,
    content="100",
  )
  inspect(
    t.crack_times_seconds.offline_slow_hashing_1e4_per_second,
    content="0.1",
  )
  inspect(
    t.crack_times_seconds.offline_fast_hashing_1e10_per_second,
    content="1e-7",
  )
  // 1000 < 1e3 + DELTA(5) => score 0
  inspect(t.score, content="0")
}

///|
/// display_time 分档。上游 `Math.round seconds / minute` 实际编译为
/// `Math.round(seconds / minute)`——先除后圆整，各档显示整数。
test "display_time buckets" {
  // guesses=1：限流场景 36 秒，其余均小于 1 秒
  let t = @zxcvbn.estimate_attack_times(1.0)
  inspect(
    t.crack_times_display.online_throttling_100_per_hour,
    content="36 seconds",
  )
  inspect(
    t.crack_times_display.online_no_throttling_10_per_second,
    content="less than a second",
  )
  inspect(
    t.crack_times_display.offline_slow_hashing_1e4_per_second,
    content="less than a second",
  )

  // guesses=10：不限流场景恰好 1 秒（==1 不加 s）
  let t = @zxcvbn.estimate_attack_times(10.0)
  inspect(
    t.crack_times_display.online_no_throttling_10_per_second,
    content="1 second",
  )
  let t = @zxcvbn.estimate_attack_times(20.0)
  inspect(
    t.crack_times_display.online_no_throttling_10_per_second,
    content="2 seconds",
  )

  // 分/时/日/月/年
  let t = @zxcvbn.estimate_attack_times(36000.0)
  inspect(
    t.crack_times_display.online_no_throttling_10_per_second,
    content="1 hour",
  )
  let t = @zxcvbn.estimate_attack_times(864000.0)
  inspect(
    t.crack_times_display.online_no_throttling_10_per_second,
    content="1 day",
  )
  let t = @zxcvbn.estimate_attack_times(26784000.0)
  inspect(
    t.crack_times_display.online_no_throttling_10_per_second,
    content="1 month",
  )
  let t = @zxcvbn.estimate_attack_times(321408000.0)
  inspect(
    t.crack_times_display.online_no_throttling_10_per_second,
    content="1 year",
  )

  // 超过一个世纪 => centuries（且不加 s，因为 upstream 没有数字）
  let t = @zxcvbn.estimate_attack_times(32140800000.0)
  inspect(
    t.crack_times_display.online_no_throttling_10_per_second,
    content="centuries",
  )
}

///|
/// 分档边界按 `Math.round(seconds / unit)` 圆整：60 秒 → 1 分钟，
/// 90 秒 → 2 分钟（JS 的 Math.round 对 .5 向上取整），不会出现分数形式。
test "display_time rounds to integers at bucket boundaries" {
  // guesses=600 => online_no_throttling = 60 秒，恰好进入分钟档 => round(60/60)=1
  let t = @zxcvbn.estimate_attack_times(600.0)
  inspect(
    t.crack_times_display.online_no_throttling_10_per_second,
    content="1 minute",
  )
  // guesses=900 => 90 秒 => round(90/60)=round(1.5)=2
  let t = @zxcvbn.estimate_attack_times(900.0)
  inspect(
    t.crack_times_display.online_no_throttling_10_per_second,
    content="2 minutes",
  )
}
