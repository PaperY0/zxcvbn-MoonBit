// Black-box tests (package `PaperY0/zxcvbn` seen from outside).
// Public behavior belongs here; internal helpers go to `zxcvbn_test.mbt`.
//
// Phase 2 收口后这里放端到端向量，例如：
//   test "official vector: zxcvbn(password)" {
//     let r = @zxcvbn.zxcvbn("password", [])
//     inspect(r.score, content="0")
//     ...
//   }
