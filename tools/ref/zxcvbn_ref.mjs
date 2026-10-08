// 差分对拍的上游参照实现：npm zxcvbn@4.4.2（= dropbox/zxcvbn 上游）。
//
// 只被 tools/diff_test.py 调用，不参与本模块发布。
//
// 输入：stdin，JSON Lines，每行一个用例
//   {"password": "...", "user_inputs": ["bob"], "reference_year": 2026}
// 输出：stdout，JSON Lines，字段与 cmd/main --batch 的 JSON 输出逐字对齐
//
// 为什么要显式覆盖 REFERENCE_YEAR：
// 上游 `scoring.REFERENCE_YEAR = new Date().getFullYear()` 是模块加载时的常量，
// 不覆盖的话对拍结果会随运行年份漂移。matching.js 与 scoring.js 都是在调用时
// 读这个属性（`scoring.REFERENCE_YEAR` / `this.REFERENCE_YEAR`），所以 require 之后
// 改写属性能生效——实测改 2026→1990，regex_guesses('1999') 从 27 变 20。
import { createRequire } from 'node:module';
import readline from 'node:readline';

const require = createRequire(import.meta.url);
const scoring = require('zxcvbn/lib/scoring');
const zxcvbn = require('zxcvbn');

// 上游 match 对象带很多本实现不输出的字段（dictionary_name/rank/l33t/…），
// 只投影出双方共有的五个，避免把上游特有字段算成"多余字段"。
function normalize_sequence(seq) {
  return seq.map((m) => ({
    i: m.i,
    j: m.j,
    pattern: m.pattern,
    token: m.token,
    guesses: m.guesses,
  }));
}

function evaluate(password, user_inputs, reference_year) {
  scoring.REFERENCE_YEAR = reference_year;
  const r = zxcvbn(password, user_inputs ?? []);
  return {
    password: r.password,
    guesses: r.guesses,
    guesses_log10: r.guesses_log10,
    score: r.score,
    crack_times_seconds: {
      online_throttling_100_per_hour:
        r.crack_times_seconds.online_throttling_100_per_hour,
      online_no_throttling_10_per_second:
        r.crack_times_seconds.online_no_throttling_10_per_second,
      offline_slow_hashing_1e4_per_second:
        r.crack_times_seconds.offline_slow_hashing_1e4_per_second,
      offline_fast_hashing_1e10_per_second:
        r.crack_times_seconds.offline_fast_hashing_1e10_per_second,
    },
    crack_times_display: {
      online_throttling_100_per_hour:
        r.crack_times_display.online_throttling_100_per_hour,
      online_no_throttling_10_per_second:
        r.crack_times_display.online_no_throttling_10_per_second,
      offline_slow_hashing_1e4_per_second:
        r.crack_times_display.offline_slow_hashing_1e4_per_second,
      offline_fast_hashing_1e10_per_second:
        r.crack_times_display.offline_fast_hashing_1e10_per_second,
    },
    sequence: normalize_sequence(r.sequence),
    feedback: {
      warning: r.feedback.warning,
      suggestions: r.feedback.suggestions,
    },
  };
}

async function main() {
  const rl = readline.createInterface({ input: process.stdin });
  for await (const line of rl) {
    const trimmed = line.trim();
    if (!trimmed) continue;
    const c = JSON.parse(trimmed);
    const out = evaluate(c.password, c.user_inputs, c.reference_year ?? 2026);
    process.stdout.write(JSON.stringify(out) + '\n');
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

// 供直接 import / 单测用
export { evaluate };
