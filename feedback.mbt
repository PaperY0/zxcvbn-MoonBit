// 建议文案：warning + suggestions。
//
// 移植来源：dropbox/zxcvbn `src/feedback.coffee`（MIT, (c) Dropbox, Inc.）
//
// 建议只针对 score <= 2 的密码给出，且绑定到序列里**最长**的那个匹配。

///|
/// 上游 `feedback.get_feedback`。
pub fn get_feedback(score : Int, sequence : Array[Match]) -> Feedback {
  // 没有任何匹配 => 兜底建议
  if sequence.length() == 0 {
    return default_feedback
  }
  // score 好或很好时不给建议
  if score > 2 {
    return { warning: "", suggestions: [], }
  }
  // 建议绑定到最长匹配（长序列里它最有信息量）
  let mut longest = sequence[0]
  for m in sequence[1:] {
    if m.token().to_array().length() > longest.token().to_array().length() {
      longest = m
    }
  }
  let is_sole_match = sequence.length() == 1
  let extra = "Add another word or two. Uncommon words are better."
  match get_match_feedback(longest, is_sole_match) {
    Some(feedback) => {
      // 前缀"再加一两个词"——任何情况下都有用
      feedback.suggestions.insert(0, extra)
      { warning: feedback.warning, suggestions: feedback.suggestions, }
    }
    None => { warning: "", suggestions: [extra], }
  }
}

///|
/// 上游 `feedback.get_match_feedback`：按最长匹配的模式给建议。
/// 上游对未覆盖的模式返回 undefined，这里对应 None。
fn get_match_feedback(m : Match, is_sole_match : Bool) -> Feedback? {
  match m {
    Dictionary(dm) => Some(get_dictionary_match_feedback(dm, is_sole_match))
    Spatial(sm) => {
      let warning = if sm.turns == 1 {
        "Straight rows of keys are easy to guess"
      } else {
        "Short keyboard patterns are easy to guess"
      }
      Some({
        warning,
        suggestions: ["Use a longer keyboard pattern with more turns"],
      })
    }
    Repeat(rm) => {
      let warning = if rm.base_token.to_array().length() == 1 {
        "Repeats like \"aaa\" are easy to guess"
      } else {
        "Repeats like \"abcabcabc\" are only slightly harder to guess than \"abc\""
      }
      Some({ warning, suggestions: ["Avoid repeated words and characters"], })
    }
    Sequence(_) =>
      Some({
        warning: "Sequences like abc or 6543 are easy to guess",
        suggestions: ["Avoid sequences"],
      })
    Regex(rm) =>
      if rm.regex_name == "recent_year" {
        Some({
          warning: "Recent years are easy to guess",
          suggestions: [
            "Avoid recent years", "Avoid years that are associated with you",
          ],
        })
      } else {
        None
      }
    Date(_) =>
      Some({
        warning: "Dates are often easy to guess",
        suggestions: ["Avoid dates and years that are associated with you"],
      })
    Bruteforce(_) => None
  }
}

///|
/// 上游 `feedback.get_dictionary_match_feedback`。
fn get_dictionary_match_feedback(
  m : DictionaryMatch,
  is_sole_match : Bool,
) -> Feedback {
  let warning = match m.dictionary_name {
    Passwords =>
      if is_sole_match && !m.l33t && !m.reversed {
        if m.rank <= 10 {
          "This is a top-10 common password"
        } else if m.rank <= 100 {
          "This is a top-100 common password"
        } else {
          "This is a very common password"
        }
      } else if m.guesses_log10 <= 4.0 {
        "This is similar to a commonly used password"
      } else {
        ""
      }
    English =>
      if is_sole_match {
        "A word by itself is easy to guess"
      } else {
        ""
      }
    Surnames | MaleNames | FemaleNames =>
      if is_sole_match {
        "Names and surnames by themselves are easy to guess"
      } else {
        "Common names and surnames are easy to guess"
      }
    // UsTvAndFilm：上游没有专门文案
    _ => ""
  }
  let suggestions : Array[String] = []
  let word = m.token
  if is_start_upper(word.to_array()) {
    suggestions.push("Capitalization doesn't help very much")
  } else if all_non_lower(word.to_array()) && word.to_lower() != word {
    suggestions.push(
      "All-uppercase is almost as easy to guess as all-lowercase",
    )
  }
  if m.reversed && word.to_array().length() >= 4 {
    suggestions.push("Reversed words aren't much harder to guess")
  }
  if m.l33t {
    suggestions.push(
      "Predictable substitutions like '@' instead of 'a' don't help very much",
    )
  }
  { warning, suggestions, }
}
