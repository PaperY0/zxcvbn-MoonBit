// 演示页逻辑。只做三件事：读输入 → 调 MoonBit 导出的函数 → 渲染。
// 所有计算都在浏览器内完成（demo/zxcvbn.js 是 MoonBit 编到 js 后端的产物），
// 没有任何 fetch / XHR。

import { zxcvbnReport } from './zxcvbn.js';

const SCENARIOS = [
  ['在线限流', '100 次/小时', 'online_throttling_100_per_hour'],
  ['在线不限流', '10 次/秒', 'online_no_throttling_10_per_second'],
  ['离线慢哈希', '10⁴ 次/秒', 'offline_slow_hashing_1e4_per_second'],
  ['离线快哈希', '10¹⁰ 次/秒', 'offline_fast_hashing_1e10_per_second'],
];

const LABELS = ['非常危险', '危险', '一般', '安全', '非常安全'];

const $ = (id) => document.getElementById(id);
const pw = $('pw');
const user = $('user');

function fmtGuesses(g) {
  if (!isFinite(g)) return '∞';
  if (g < 1e4) return String(Math.round(g));
  // 用上标数字避免引入大数字格式化依赖
  const sup = { '0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴', '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹' };
  const exp = Math.floor(Math.log10(g));
  const mantissa = (g / 10 ** exp).toFixed(1);
  const supExp = String(exp).split('').map((c) => sup[c]).join('');
  return `${mantissa}×10${supExp}`;
}

function render(r) {
  $('result').hidden = false;

  const score = r.score ?? 0;
  const segs = $('bar').children;
  for (let i = 0; i < segs.length; i++) {
    segs[i].dataset.on = i <= score ? '1' : '0';
  }
  $('score-label').textContent = LABELS[score] ?? '—';
  $('score').textContent = `${score} / 4`;
  $('guesses').textContent = fmtGuesses(r.guesses);
  $('log10').textContent = r.guesses_log10.toFixed(2);

  const tb = $('times');
  tb.replaceChildren();
  for (const [name, rate, key] of SCENARIOS) {
    const tr = document.createElement('tr');
    for (const v of [name, rate, r.crack_times_display[key] ?? '—']) {
      const td = document.createElement('td');
      td.textContent = v;
      tr.appendChild(td);
    }
    tb.appendChild(tr);
  }

  const ul = $('patterns');
  ul.replaceChildren();
  if (!r.sequence || r.sequence.length === 0) {
    const li = document.createElement('li');
    li.className = 'empty';
    li.textContent = '（没有任何可识别模式——这通常意味着只能靠暴力穷举）';
    ul.appendChild(li);
  } else {
    for (const m of r.sequence) {
      const li = document.createElement('li');
      const tag = document.createElement('span');
      tag.className = 'tag';
      tag.textContent = m.pattern;
      const tok = document.createElement('code');
      tok.textContent = m.token;
      const g = document.createElement('span');
      g.className = 'g';
      g.textContent = `${fmtGuesses(m.guesses)} 次`;
      const idx = document.createElement('span');
      idx.className = 'idx';
      idx.textContent = `[${m.i}, ${m.j}]`;
      li.append(tag, tok, g, idx);
      ul.appendChild(li);
    }
  }

  const warn = r.feedback?.warning ?? '';
  const sugg = r.feedback?.suggestions ?? [];
  const fb = $('feedback');
  if (warn || sugg.length) {
    fb.hidden = false;
    $('warning').textContent = warn;
    const su = $('suggestions');
    su.replaceChildren();
    for (const s of sugg) {
      const li = document.createElement('li');
      li.textContent = s;
      su.appendChild(li);
    }
  } else {
    // 必须一并清空：否则 DOM 里留着上一个密码的 warning，
    // 虽然整块被 hidden 藏住了，但读 textContent 会拿到脏数据。
    $('warning').textContent = '';
    $('suggestions').replaceChildren();
    fb.hidden = true;
  }
}

function update() {
  const userInputs = user.value
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
  try {
    render(JSON.parse(zxcvbnReport(pw.value, userInputs)));
  } catch (e) {
    // 理论上不会发生：输入是任意字符串，序列化总是成功的。
    console.error(e);
  }
}

pw.addEventListener('input', update);
user.addEventListener('input', update);
update();
