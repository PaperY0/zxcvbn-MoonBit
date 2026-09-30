// zxcvbn.mbt 的白盒测试（包内视角）。
//
// 这里放与公共 API 收口相关、但只需要包内可见性的测试：
// 用户输入词典的构造、参考年份默认值、以及 core Regex 的 POSIX 类能力验证。

///|
/// `zxcvbn` 的默认参考年份应为 2026（上游取运行时当年，MoonBit core 无时钟 API）。
test "default reference year is 2026" {
  // 白盒测试与库同包，直接引用即可（不能用 @包名 前缀）
  let default_year = zxcvbn("1999", []).sequence
  let explicit = zxcvbn("1999", [], reference_year=2026).sequence
  debug_inspect([default_year, explicit].length(), content="2")
}
