# demo/ — 浏览器强度条

最小可用示例：输入密码，实时显示 0–4 强度分、猜测次数、四种攻击场景的破解耗时、
攻击者会先试的模式序列，以及修改建议。

**密码不离开浏览器**：`demo/zxcvbn.js` 是 MoonBit 核心库编译到 js 后端的产物，
全部计算在本地完成，没有任何网络请求（打开 DevTools 的 Network 面板可以验证）。

## 跑起来

```bash
bash demo/build.sh                       # 生成 demo/zxcvbn.js（约 1.3 MB，含 93,855 词词典）
python -m http.server -d demo 8000       # ES module 需要 http://，file:// 不行
# 打开 http://localhost:8000/
```

## 在线版本

推送到 main 后由 `.github/workflows/pages.yml` 自动部署到 GitHub Pages。

## 结构

| 文件 | 作用 |
| --- | --- |
| `web/zxcvbn_web.mbt` | MoonBit 侧唯一导出：`zxcvbnReport(password, user_inputs) -> String` |
| `web/moon.pkg.json` | `pkgtype: foreign_library` + `link.js { format: esm }` |
| `index.html` / `app.js` / `style.css` | 前端 |
| `zxcvbn.js` | **生成文件**，勿手改 |

## 为什么是这个构建方式

几个 MoonBit 工具链上实测出来的结论，写下来省得下次重新踩：

1. **必须用 `foreign_library` + `link.js.format = "esm"`。** js 后端默认只给
   *可执行包*出 IIFE——那会立刻执行 `main()`，浏览器里没法用；`foreign_library`
   配上 esm 才产出带 `export { ... }` 的 ES module。
2. **值编组只对简单类型有效。** MoonBit `String` ↔ JS string、`Array[String]` ↔
   JS array、`Int`/`Double` ↔ number，都是自动的。**结构体没有编组**，所以导出
   函数返回 JSON 字符串（`Entropy::to_json`），前端 `JSON.parse`。
3. **导出名要显式指定。** 不加 `#export_name` 的话导出的是编译器 mangling 后的
   名字（形如 `_M0FP47PaperY06zxcvbn4demo3web6report`）。
4. **本 demo 不用 wasm-gc 目标。** 开了 `WasmGcLinkConfig.use-js-builtin-string`
   会把 93,855 个词典词全部变成 wasm import（实测 import 段 776 KB，不可用）；
   不开则要手写 MoonBit 字符串表示的编组。js 目标零 glue、零风险。
   wasm-gc / wasm 后端的能力由 CI 的三后端测试矩阵覆盖，不靠这个 demo 证明。

## 许可

页面里的算法、词典与文案来自 `dropbox/zxcvbn`（MIT, (c) Dropbox, Inc.），
本项目以 MIT 发布。
