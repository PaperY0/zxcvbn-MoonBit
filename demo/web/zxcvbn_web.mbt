// 浏览器侧的唯一入口。
//
// 为什么是 foreign_library + `link.js.format = esm`：
// MoonBit 的 js 后端只给**可执行包**出 IIFE（会立刻跑 main，浏览器用不了），
// 给 foreign_library 配了 esm 之后才产出带 `export { ... }` 的 ES module。
// 实测 `moon build --target js` 后 `import { zxcvbnReport } from './lib.js'`
// 在浏览器与 Node 里都能直接用。
//
// 值编组是自动的、且只对简单类型有效：MoonBit `String` ↔ JS string，
// `Array[String]` ↔ JS array，`Int`/`Double` ↔ number。**结构体没有编组**，
// 所以这里返回 JSON 字符串（`Entropy::to_json`），由 JS 侧 `JSON.parse`。
//
// 注意 wasm-gc 目标目前不用于本 demo：开了 `use-js-builtin-string` 会把
// 93,855 个词典词全部变成 wasm import（实测 776KB 的 import 段），不开则要
// 手写 MoonBit 字符串表示的编组。js 目标零 glue、零风险，wasm-gc 的能力由
// CI 的三后端测试矩阵覆盖。

///|
/// 评估一个密码，返回 JSON 字符串（格式见 `Entropy::to_json`）。
///
/// `user_inputs` 传与用户相关的词（用户名/邮箱），命中时会显著降低强度估计；
/// 演示页用它演示"拿自己名字当密码"为什么危险。
#export_name("zxcvbnReport")
pub fn report(password : String, user_inputs : Array[String]) -> String {
  @lib.zxcvbn(password, user_inputs).to_json()
}
