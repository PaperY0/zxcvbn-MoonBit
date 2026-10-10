# Changelog

All notable changes to this project will be documented in this file.
Versioning follows [Semantic Versioning](https://semver.org/).

## [0.1.0] — 2026-10-08

First public release on [mooncakes.io](https://mooncakes.io).

### Core
- 8 pattern matchers: dictionaries (6 lists, 93,855 words), reverse dictionary,
  l33t substitutions (17-rule table + subset enumeration), keyboard adjacency
  (qwerty/dvorak/keypad/mac_keypad), repeats, sequences, regex (years),
  dates (separated and unseparated)
- Minimum-guesses DP scoring with factorial-length penalty
- Score 0–4, entropy (guesses / log10), four-scenario crack time estimates,
  actionable feedback (warning + suggestions)
- Pure computation, no IO; wasm / wasm-gc / js targets

### API
- `zxcvbn(password, user_inputs, reference_year?)` → `Entropy`
- Low-level matchers callable individually for testing and embedding
- CLI: `moon run cmd/main -- "password"` with `--json`, `--batch`, `--user`, `--year`

### Quality
- 56 tests, all passing on wasm / wasm-gc / js
- Differential testing against zxcvbn@4.4.2: 742 cases, 0 unexpected mismatches
- CI: three-target matrix + fmt/check/interface gates
- Coverage: 83 uncovered lines (all defensive branches / CLI / edge-case JSON escapes)

### Deliberate deviations from upstream zxcvbn
- Unicode scalar-value indexing (not UTF-16 code units)
- `Double` for guesses (not integer, avoids silent overflow on long passwords)
- `reference_year` parameterized (default 2026, MoonBit has no clock API)
- `recent_year` regex upgraded to `19\d\d|20\d\d`
- Dictionary match length capped to longest word in any dictionary
- No global state: pure function, thread-safe
