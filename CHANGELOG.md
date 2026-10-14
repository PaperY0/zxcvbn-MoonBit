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
- 57 tests, all passing on wasm / wasm-gc / js
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

## [Unreleased]

### Bug fixes
- Dictionary matching: replace `to_ascii_lowercase()` with `String::to_lower()` via
  new `lower()` helper, fixing case-insensitive matching for Latin-1 Supplement
  characters (e.g. Ü→ü) in user_inputs
- CLI `--year` argument: add bounds check (1900–2100), fallback to 2026
- date_match inner loop: `j >= len` branch now `break` instead of `j += 1; continue`
- Fix date_match loop: `j += 1; continue` → `break` when `j >= len`

### Documentation
- Add CHANGELOG.md, COVERAGE.md
- Sync test count across README.md and README.mbt.md
- Document MoonBit `String::to_lower()` Unicode scope limitation (Greek uppercase
  not handled)

### Known limitation
- Greek uppercase case folding (Α→α): MoonBit `String::to_lower()` does not convert
  Greek uppercase to lowercase. User_inputs containing Greek names with case variants
  may not match. Requires MoonBit stdlib enhancement for full Unicode case folding.
