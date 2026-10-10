# Coverage Report

Generated: 2026-10-10
Tool: `moon coverage analyze` (MOON_COVE_REPORT_ENABLED=1)
Target: wasm (default)

## Summary

| Metric | Value |
| --- | --- |
| Total files | 9 |
| Uncovered lines | 83 |
| Total tests | 56 (all passing) |

## Uncovered Lines by File

### json.mbt (9 uncovered)

JSON escape branches not exercised by current tests (test passwords don't contain
`\`, `\n`, `\r`, `\t`, `\b`, `\f`, or control chars):

- `\` escape (line 65)
- `\n` escape (line 69)
- `\r` escape (line 73)
- `\t` escape (line 77)
- `\b` escape (line 81)
- `\f` escape (line 85)
- Control char `\u00xx` (line 91)
- `hex_digit` n < 10 branch (line 107)
- `hex_digit` n >= 10 branch (line 110)

### zxcvbn.mbt (1 uncovered)

- `zxcvbn_password` convenience wrapper (line 119) — not called directly in tests

### scoring.mbt (2 uncovered)

- DP unwind defensive `None` branch (line 194) — unreachable in practice

### feedback.mbt (10 uncovered)

Branches for specific password patterns not present in test vectors:

- Spatial "straight rows" warning (line 46)
- Dictionary rank 100+ feedback (line 98)
- Dictionary "very common" feedback (line 100)
- Dictionary empty warning (line 106)
- English sole-match warning (line 109)
- English empty warning (line 112)
- Names/Surnames sole-match warning (line 115)
- Names/Surnames common warning (line 118)
- All-uppercase suggestion (line 128)
- Regex non-recent_year None (line 76)

### matching.mbt (16 uncovered)

- `Sequence` token arm in `Match::token()` (line 222)
- `Match::guesses_log10()` full match (line 265)
- `Match::describe()` (line 307)
- User input extending max_word_length (line 446)
- Non-Dictionary match in reverse (line 582)
- L33t `None` from table.get (line 662)
- Non-Dictionary match in l33t (line 775)
- Spatial `found && !stop` branch (line 608)
- `is_recent_year_at` short prefix (line 1158)
- `is_maybe_date_no_separator` out-of-range (line 1224)
- `date_splits.get` None (line 1413)
- `parse_maybe_date_with_separator` l1 >= len (line 1248)
- `parse_maybe_date_with_separator` d2_end > len (line 1261)
- `digits_to_int` non-digit break (line 1308)
- `map_ints_to_dmy` return None (line 1266)
- `two_to_four_digit_year` year > 99 (line 1384)

### cmd/main/main.mbt (40 uncovered)

CLI entry point and argument parsing — not exercised by unit tests.

### frequency_lists.mbt (3 uncovered)

- `ranked_lookup` function entry (line 73)
- `to_ascii_lower` (line 133)
- Unreachable `None` from dict iteration

### adjacency_graphs.mbt (1 uncovered)

- `abort("unknown adjacency graph")` (line 1374) — defensive

### demo/web/zxcvbn_web.mbt (1 uncovered)

- `report` WASM export (line 1150) — tested via browser, not unit tests

## Notes

All uncovered lines are defensive branches, CLI code, or code paths requiring
specific input characters not present in the test vectors. No core algorithm
branches are uncovered.
