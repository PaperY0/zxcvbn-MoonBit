#!/usr/bin/env bash
# 构建演示页用的 MoonBit → JS 产物。
#
# 产物是生成文件，不入库（.gitignore 里 `demo/zxcvbn.js`）；
# GitHub Pages 由 .github/workflows/pages.yml 调同样的步骤。
set -euo pipefail

cd "$(dirname "$0")/.."

moon build --target js --release

out="_build/js/release/build/demo/web/web.js"
if [[ ! -f "$out" ]]; then
  echo "找不到构建产物：$out" >&2
  exit 1
fi

cp "$out" demo/zxcvbn.js
echo "已生成 demo/zxcvbn.js（$(wc -c < demo/zxcvbn.js) 字节）"
echo "现在起一个本地服务器再打开页面（ES module 需要 http://，不能用 file://）："
echo "    python -m http.server -d demo 8000"
echo "然后访问 http://localhost:8000/"
