// 由 tools/gen_adjacency_graphs.py 从 data/upstream/dropbox-zxcvbn/src/
// adjacency_graphs.coffee 生成（MIT, (c) Dropbox, Inc.），请勿手工编辑。
//
// 重新生成：python3 tools/gen_adjacency_graphs.py
//
// 邻接图语义与上游一致：
// * 键为键盘上的一个键（同时收录大小写两种形态，与上游相同）；
// * 值为长度 6（qwerty/dvorak）或 8（keypad/mac_keypad）的方向槽数组，
//   下标即 spatial_match_helper 里 `cur_direction` 的递增序号；
// * 条目 `(未移位, 移位)`；`None` 表示该方向无相邻键；
// * 单字符条目（keypad 系）第二位填同字符，对应上游字符串 index 恒为 0 的语义。

///|
/// `qwerty` 邻接图（上游 `adjacency_graphs.qwerty`）。
///
/// 每个条目 `(未移位字符, 移位字符)`；`None` 是该方向没有相邻键。占位的 `None`
/// 必须保留——数组下标即 spatial_match_helper 的 direction 计数。
let qwerty : Lazy[Map[Char, Array[(Char, Char)?]]] = Lazy(() => {
  Map([
    (
      '!',
      [Some(('`', '~')), None, None, Some(('2', '@')), Some(('q', 'Q')), None],
    ),
    (
      '"',
      [
        Some((';', ':')),
        Some(('[', '{')),
        Some((']', '}')),
        None,
        None,
        Some(('/', '?')),
      ],
    ),
    (
      '#',
      [
        Some(('2', '@')),
        None,
        None,
        Some(('4', '$')),
        Some(('e', 'E')),
        Some(('w', 'W')),
      ],
    ),
    (
      '$',
      [
        Some(('3', '#')),
        None,
        None,
        Some(('5', '%')),
        Some(('r', 'R')),
        Some(('e', 'E')),
      ],
    ),
    (
      '%',
      [
        Some(('4', '$')),
        None,
        None,
        Some(('6', '^')),
        Some(('t', 'T')),
        Some(('r', 'R')),
      ],
    ),
    (
      '&',
      [
        Some(('6', '^')),
        None,
        None,
        Some(('8', '*')),
        Some(('u', 'U')),
        Some(('y', 'Y')),
      ],
    ),
    (
      '\'',
      [
        Some((';', ':')),
        Some(('[', '{')),
        Some((']', '}')),
        None,
        None,
        Some(('/', '?')),
      ],
    ),
    (
      '(',
      [
        Some(('8', '*')),
        None,
        None,
        Some(('0', ')')),
        Some(('o', 'O')),
        Some(('i', 'I')),
      ],
    ),
    (
      ')',
      [
        Some(('9', '(')),
        None,
        None,
        Some(('-', '_')),
        Some(('p', 'P')),
        Some(('o', 'O')),
      ],
    ),
    (
      '*',
      [
        Some(('7', '&')),
        None,
        None,
        Some(('9', '(')),
        Some(('i', 'I')),
        Some(('u', 'U')),
      ],
    ),
    (
      '+',
      [Some(('-', '_')), None, None, None, Some((']', '}')), Some(('[', '{'))],
    ),
    (
      ',',
      [
        Some(('m', 'M')),
        Some(('k', 'K')),
        Some(('l', 'L')),
        Some(('.', '>')),
        None,
        None,
      ],
    ),
    (
      '-',
      [
        Some(('0', ')')),
        None,
        None,
        Some(('=', '+')),
        Some(('[', '{')),
        Some(('p', 'P')),
      ],
    ),
    (
      '.',
      [
        Some((',', '<')),
        Some(('l', 'L')),
        Some((';', ':')),
        Some(('/', '?')),
        None,
        None,
      ],
    ),
    (
      '/',
      [Some(('.', '>')), Some((';', ':')), Some(('\'', '"')), None, None, None],
    ),
    (
      '0',
      [
        Some(('9', '(')),
        None,
        None,
        Some(('-', '_')),
        Some(('p', 'P')),
        Some(('o', 'O')),
      ],
    ),
    (
      '1',
      [Some(('`', '~')), None, None, Some(('2', '@')), Some(('q', 'Q')), None],
    ),
    (
      '2',
      [
        Some(('1', '!')),
        None,
        None,
        Some(('3', '#')),
        Some(('w', 'W')),
        Some(('q', 'Q')),
      ],
    ),
    (
      '3',
      [
        Some(('2', '@')),
        None,
        None,
        Some(('4', '$')),
        Some(('e', 'E')),
        Some(('w', 'W')),
      ],
    ),
    (
      '4',
      [
        Some(('3', '#')),
        None,
        None,
        Some(('5', '%')),
        Some(('r', 'R')),
        Some(('e', 'E')),
      ],
    ),
    (
      '5',
      [
        Some(('4', '$')),
        None,
        None,
        Some(('6', '^')),
        Some(('t', 'T')),
        Some(('r', 'R')),
      ],
    ),
    (
      '6',
      [
        Some(('5', '%')),
        None,
        None,
        Some(('7', '&')),
        Some(('y', 'Y')),
        Some(('t', 'T')),
      ],
    ),
    (
      '7',
      [
        Some(('6', '^')),
        None,
        None,
        Some(('8', '*')),
        Some(('u', 'U')),
        Some(('y', 'Y')),
      ],
    ),
    (
      '8',
      [
        Some(('7', '&')),
        None,
        None,
        Some(('9', '(')),
        Some(('i', 'I')),
        Some(('u', 'U')),
      ],
    ),
    (
      '9',
      [
        Some(('8', '*')),
        None,
        None,
        Some(('0', ')')),
        Some(('o', 'O')),
        Some(('i', 'I')),
      ],
    ),
    (
      ':',
      [
        Some(('l', 'L')),
        Some(('p', 'P')),
        Some(('[', '{')),
        Some(('\'', '"')),
        Some(('/', '?')),
        Some(('.', '>')),
      ],
    ),
    (
      ';',
      [
        Some(('l', 'L')),
        Some(('p', 'P')),
        Some(('[', '{')),
        Some(('\'', '"')),
        Some(('/', '?')),
        Some(('.', '>')),
      ],
    ),
    (
      '<',
      [
        Some(('m', 'M')),
        Some(('k', 'K')),
        Some(('l', 'L')),
        Some(('.', '>')),
        None,
        None,
      ],
    ),
    (
      '=',
      [Some(('-', '_')), None, None, None, Some((']', '}')), Some(('[', '{'))],
    ),
    (
      '>',
      [
        Some((',', '<')),
        Some(('l', 'L')),
        Some((';', ':')),
        Some(('/', '?')),
        None,
        None,
      ],
    ),
    (
      '?',
      [Some(('.', '>')), Some((';', ':')), Some(('\'', '"')), None, None, None],
    ),
    (
      '@',
      [
        Some(('1', '!')),
        None,
        None,
        Some(('3', '#')),
        Some(('w', 'W')),
        Some(('q', 'Q')),
      ],
    ),
    (
      'A',
      [
        None,
        Some(('q', 'Q')),
        Some(('w', 'W')),
        Some(('s', 'S')),
        Some(('z', 'Z')),
        None,
      ],
    ),
    (
      'B',
      [
        Some(('v', 'V')),
        Some(('g', 'G')),
        Some(('h', 'H')),
        Some(('n', 'N')),
        None,
        None,
      ],
    ),
    (
      'C',
      [
        Some(('x', 'X')),
        Some(('d', 'D')),
        Some(('f', 'F')),
        Some(('v', 'V')),
        None,
        None,
      ],
    ),
    (
      'D',
      [
        Some(('s', 'S')),
        Some(('e', 'E')),
        Some(('r', 'R')),
        Some(('f', 'F')),
        Some(('c', 'C')),
        Some(('x', 'X')),
      ],
    ),
    (
      'E',
      [
        Some(('w', 'W')),
        Some(('3', '#')),
        Some(('4', '$')),
        Some(('r', 'R')),
        Some(('d', 'D')),
        Some(('s', 'S')),
      ],
    ),
    (
      'F',
      [
        Some(('d', 'D')),
        Some(('r', 'R')),
        Some(('t', 'T')),
        Some(('g', 'G')),
        Some(('v', 'V')),
        Some(('c', 'C')),
      ],
    ),
    (
      'G',
      [
        Some(('f', 'F')),
        Some(('t', 'T')),
        Some(('y', 'Y')),
        Some(('h', 'H')),
        Some(('b', 'B')),
        Some(('v', 'V')),
      ],
    ),
    (
      'H',
      [
        Some(('g', 'G')),
        Some(('y', 'Y')),
        Some(('u', 'U')),
        Some(('j', 'J')),
        Some(('n', 'N')),
        Some(('b', 'B')),
      ],
    ),
    (
      'I',
      [
        Some(('u', 'U')),
        Some(('8', '*')),
        Some(('9', '(')),
        Some(('o', 'O')),
        Some(('k', 'K')),
        Some(('j', 'J')),
      ],
    ),
    (
      'J',
      [
        Some(('h', 'H')),
        Some(('u', 'U')),
        Some(('i', 'I')),
        Some(('k', 'K')),
        Some(('m', 'M')),
        Some(('n', 'N')),
      ],
    ),
    (
      'K',
      [
        Some(('j', 'J')),
        Some(('i', 'I')),
        Some(('o', 'O')),
        Some(('l', 'L')),
        Some((',', '<')),
        Some(('m', 'M')),
      ],
    ),
    (
      'L',
      [
        Some(('k', 'K')),
        Some(('o', 'O')),
        Some(('p', 'P')),
        Some((';', ':')),
        Some(('.', '>')),
        Some((',', '<')),
      ],
    ),
    (
      'M',
      [
        Some(('n', 'N')),
        Some(('j', 'J')),
        Some(('k', 'K')),
        Some((',', '<')),
        None,
        None,
      ],
    ),
    (
      'N',
      [
        Some(('b', 'B')),
        Some(('h', 'H')),
        Some(('j', 'J')),
        Some(('m', 'M')),
        None,
        None,
      ],
    ),
    (
      'O',
      [
        Some(('i', 'I')),
        Some(('9', '(')),
        Some(('0', ')')),
        Some(('p', 'P')),
        Some(('l', 'L')),
        Some(('k', 'K')),
      ],
    ),
    (
      'P',
      [
        Some(('o', 'O')),
        Some(('0', ')')),
        Some(('-', '_')),
        Some(('[', '{')),
        Some((';', ':')),
        Some(('l', 'L')),
      ],
    ),
    (
      'Q',
      [
        None,
        Some(('1', '!')),
        Some(('2', '@')),
        Some(('w', 'W')),
        Some(('a', 'A')),
        None,
      ],
    ),
    (
      'R',
      [
        Some(('e', 'E')),
        Some(('4', '$')),
        Some(('5', '%')),
        Some(('t', 'T')),
        Some(('f', 'F')),
        Some(('d', 'D')),
      ],
    ),
    (
      'S',
      [
        Some(('a', 'A')),
        Some(('w', 'W')),
        Some(('e', 'E')),
        Some(('d', 'D')),
        Some(('x', 'X')),
        Some(('z', 'Z')),
      ],
    ),
    (
      'T',
      [
        Some(('r', 'R')),
        Some(('5', '%')),
        Some(('6', '^')),
        Some(('y', 'Y')),
        Some(('g', 'G')),
        Some(('f', 'F')),
      ],
    ),
    (
      'U',
      [
        Some(('y', 'Y')),
        Some(('7', '&')),
        Some(('8', '*')),
        Some(('i', 'I')),
        Some(('j', 'J')),
        Some(('h', 'H')),
      ],
    ),
    (
      'V',
      [
        Some(('c', 'C')),
        Some(('f', 'F')),
        Some(('g', 'G')),
        Some(('b', 'B')),
        None,
        None,
      ],
    ),
    (
      'W',
      [
        Some(('q', 'Q')),
        Some(('2', '@')),
        Some(('3', '#')),
        Some(('e', 'E')),
        Some(('s', 'S')),
        Some(('a', 'A')),
      ],
    ),
    (
      'X',
      [
        Some(('z', 'Z')),
        Some(('s', 'S')),
        Some(('d', 'D')),
        Some(('c', 'C')),
        None,
        None,
      ],
    ),
    (
      'Y',
      [
        Some(('t', 'T')),
        Some(('6', '^')),
        Some(('7', '&')),
        Some(('u', 'U')),
        Some(('h', 'H')),
        Some(('g', 'G')),
      ],
    ),
    (
      'Z',
      [None, Some(('a', 'A')), Some(('s', 'S')), Some(('x', 'X')), None, None],
    ),
    (
      '[',
      [
        Some(('p', 'P')),
        Some(('-', '_')),
        Some(('=', '+')),
        Some((']', '}')),
        Some(('\'', '"')),
        Some((';', ':')),
      ],
    ),
    ('\\', [Some((']', '}')), None, None, None, None, None]),
    (
      ']',
      [
        Some(('[', '{')),
        Some(('=', '+')),
        None,
        Some(('\\', '|')),
        None,
        Some(('\'', '"')),
      ],
    ),
    (
      '^',
      [
        Some(('5', '%')),
        None,
        None,
        Some(('7', '&')),
        Some(('y', 'Y')),
        Some(('t', 'T')),
      ],
    ),
    (
      '_',
      [
        Some(('0', ')')),
        None,
        None,
        Some(('=', '+')),
        Some(('[', '{')),
        Some(('p', 'P')),
      ],
    ),
    ('`', [None, None, None, Some(('1', '!')), None, None]),
    (
      'a',
      [
        None,
        Some(('q', 'Q')),
        Some(('w', 'W')),
        Some(('s', 'S')),
        Some(('z', 'Z')),
        None,
      ],
    ),
    (
      'b',
      [
        Some(('v', 'V')),
        Some(('g', 'G')),
        Some(('h', 'H')),
        Some(('n', 'N')),
        None,
        None,
      ],
    ),
    (
      'c',
      [
        Some(('x', 'X')),
        Some(('d', 'D')),
        Some(('f', 'F')),
        Some(('v', 'V')),
        None,
        None,
      ],
    ),
    (
      'd',
      [
        Some(('s', 'S')),
        Some(('e', 'E')),
        Some(('r', 'R')),
        Some(('f', 'F')),
        Some(('c', 'C')),
        Some(('x', 'X')),
      ],
    ),
    (
      'e',
      [
        Some(('w', 'W')),
        Some(('3', '#')),
        Some(('4', '$')),
        Some(('r', 'R')),
        Some(('d', 'D')),
        Some(('s', 'S')),
      ],
    ),
    (
      'f',
      [
        Some(('d', 'D')),
        Some(('r', 'R')),
        Some(('t', 'T')),
        Some(('g', 'G')),
        Some(('v', 'V')),
        Some(('c', 'C')),
      ],
    ),
    (
      'g',
      [
        Some(('f', 'F')),
        Some(('t', 'T')),
        Some(('y', 'Y')),
        Some(('h', 'H')),
        Some(('b', 'B')),
        Some(('v', 'V')),
      ],
    ),
    (
      'h',
      [
        Some(('g', 'G')),
        Some(('y', 'Y')),
        Some(('u', 'U')),
        Some(('j', 'J')),
        Some(('n', 'N')),
        Some(('b', 'B')),
      ],
    ),
    (
      'i',
      [
        Some(('u', 'U')),
        Some(('8', '*')),
        Some(('9', '(')),
        Some(('o', 'O')),
        Some(('k', 'K')),
        Some(('j', 'J')),
      ],
    ),
    (
      'j',
      [
        Some(('h', 'H')),
        Some(('u', 'U')),
        Some(('i', 'I')),
        Some(('k', 'K')),
        Some(('m', 'M')),
        Some(('n', 'N')),
      ],
    ),
    (
      'k',
      [
        Some(('j', 'J')),
        Some(('i', 'I')),
        Some(('o', 'O')),
        Some(('l', 'L')),
        Some((',', '<')),
        Some(('m', 'M')),
      ],
    ),
    (
      'l',
      [
        Some(('k', 'K')),
        Some(('o', 'O')),
        Some(('p', 'P')),
        Some((';', ':')),
        Some(('.', '>')),
        Some((',', '<')),
      ],
    ),
    (
      'm',
      [
        Some(('n', 'N')),
        Some(('j', 'J')),
        Some(('k', 'K')),
        Some((',', '<')),
        None,
        None,
      ],
    ),
    (
      'n',
      [
        Some(('b', 'B')),
        Some(('h', 'H')),
        Some(('j', 'J')),
        Some(('m', 'M')),
        None,
        None,
      ],
    ),
    (
      'o',
      [
        Some(('i', 'I')),
        Some(('9', '(')),
        Some(('0', ')')),
        Some(('p', 'P')),
        Some(('l', 'L')),
        Some(('k', 'K')),
      ],
    ),
    (
      'p',
      [
        Some(('o', 'O')),
        Some(('0', ')')),
        Some(('-', '_')),
        Some(('[', '{')),
        Some((';', ':')),
        Some(('l', 'L')),
      ],
    ),
    (
      'q',
      [
        None,
        Some(('1', '!')),
        Some(('2', '@')),
        Some(('w', 'W')),
        Some(('a', 'A')),
        None,
      ],
    ),
    (
      'r',
      [
        Some(('e', 'E')),
        Some(('4', '$')),
        Some(('5', '%')),
        Some(('t', 'T')),
        Some(('f', 'F')),
        Some(('d', 'D')),
      ],
    ),
    (
      's',
      [
        Some(('a', 'A')),
        Some(('w', 'W')),
        Some(('e', 'E')),
        Some(('d', 'D')),
        Some(('x', 'X')),
        Some(('z', 'Z')),
      ],
    ),
    (
      't',
      [
        Some(('r', 'R')),
        Some(('5', '%')),
        Some(('6', '^')),
        Some(('y', 'Y')),
        Some(('g', 'G')),
        Some(('f', 'F')),
      ],
    ),
    (
      'u',
      [
        Some(('y', 'Y')),
        Some(('7', '&')),
        Some(('8', '*')),
        Some(('i', 'I')),
        Some(('j', 'J')),
        Some(('h', 'H')),
      ],
    ),
    (
      'v',
      [
        Some(('c', 'C')),
        Some(('f', 'F')),
        Some(('g', 'G')),
        Some(('b', 'B')),
        None,
        None,
      ],
    ),
    (
      'w',
      [
        Some(('q', 'Q')),
        Some(('2', '@')),
        Some(('3', '#')),
        Some(('e', 'E')),
        Some(('s', 'S')),
        Some(('a', 'A')),
      ],
    ),
    (
      'x',
      [
        Some(('z', 'Z')),
        Some(('s', 'S')),
        Some(('d', 'D')),
        Some(('c', 'C')),
        None,
        None,
      ],
    ),
    (
      'y',
      [
        Some(('t', 'T')),
        Some(('6', '^')),
        Some(('7', '&')),
        Some(('u', 'U')),
        Some(('h', 'H')),
        Some(('g', 'G')),
      ],
    ),
    (
      'z',
      [None, Some(('a', 'A')), Some(('s', 'S')), Some(('x', 'X')), None, None],
    ),
    (
      '{',
      [
        Some(('p', 'P')),
        Some(('-', '_')),
        Some(('=', '+')),
        Some((']', '}')),
        Some(('\'', '"')),
        Some((';', ':')),
      ],
    ),
    ('|', [Some((']', '}')), None, None, None, None, None]),
    (
      '}',
      [
        Some(('[', '{')),
        Some(('=', '+')),
        None,
        Some(('\\', '|')),
        None,
        Some(('\'', '"')),
      ],
    ),
    ('~', [None, None, None, Some(('1', '!')), None, None]),
  ])
})

///|
/// `dvorak` 邻接图（上游 `adjacency_graphs.dvorak`）。
///
/// 每个条目 `(未移位字符, 移位字符)`；`None` 是该方向没有相邻键。占位的 `None`
/// 必须保留——数组下标即 spatial_match_helper 的 direction 计数。
let dvorak : Lazy[Map[Char, Array[(Char, Char)?]]] = Lazy(() => {
  Map([
    (
      '!',
      [Some(('`', '~')), None, None, Some(('2', '@')), Some(('\'', '"')), None],
    ),
    (
      '"',
      [
        None,
        Some(('1', '!')),
        Some(('2', '@')),
        Some((',', '<')),
        Some(('a', 'A')),
        None,
      ],
    ),
    (
      '#',
      [
        Some(('2', '@')),
        None,
        None,
        Some(('4', '$')),
        Some(('.', '>')),
        Some((',', '<')),
      ],
    ),
    (
      '$',
      [
        Some(('3', '#')),
        None,
        None,
        Some(('5', '%')),
        Some(('p', 'P')),
        Some(('.', '>')),
      ],
    ),
    (
      '%',
      [
        Some(('4', '$')),
        None,
        None,
        Some(('6', '^')),
        Some(('y', 'Y')),
        Some(('p', 'P')),
      ],
    ),
    (
      '&',
      [
        Some(('6', '^')),
        None,
        None,
        Some(('8', '*')),
        Some(('g', 'G')),
        Some(('f', 'F')),
      ],
    ),
    (
      '\'',
      [
        None,
        Some(('1', '!')),
        Some(('2', '@')),
        Some((',', '<')),
        Some(('a', 'A')),
        None,
      ],
    ),
    (
      '(',
      [
        Some(('8', '*')),
        None,
        None,
        Some(('0', ')')),
        Some(('r', 'R')),
        Some(('c', 'C')),
      ],
    ),
    (
      ')',
      [
        Some(('9', '(')),
        None,
        None,
        Some(('[', '{')),
        Some(('l', 'L')),
        Some(('r', 'R')),
      ],
    ),
    (
      '*',
      [
        Some(('7', '&')),
        None,
        None,
        Some(('9', '(')),
        Some(('c', 'C')),
        Some(('g', 'G')),
      ],
    ),
    (
      '+',
      [
        Some(('/', '?')),
        Some((']', '}')),
        None,
        Some(('\\', '|')),
        None,
        Some(('-', '_')),
      ],
    ),
    (
      ',',
      [
        Some(('\'', '"')),
        Some(('2', '@')),
        Some(('3', '#')),
        Some(('.', '>')),
        Some(('o', 'O')),
        Some(('a', 'A')),
      ],
    ),
    (
      '-',
      [
        Some(('s', 'S')),
        Some(('/', '?')),
        Some(('=', '+')),
        None,
        None,
        Some(('z', 'Z')),
      ],
    ),
    (
      '.',
      [
        Some((',', '<')),
        Some(('3', '#')),
        Some(('4', '$')),
        Some(('p', 'P')),
        Some(('e', 'E')),
        Some(('o', 'O')),
      ],
    ),
    (
      '/',
      [
        Some(('l', 'L')),
        Some(('[', '{')),
        Some((']', '}')),
        Some(('=', '+')),
        Some(('-', '_')),
        Some(('s', 'S')),
      ],
    ),
    (
      '0',
      [
        Some(('9', '(')),
        None,
        None,
        Some(('[', '{')),
        Some(('l', 'L')),
        Some(('r', 'R')),
      ],
    ),
    (
      '1',
      [Some(('`', '~')), None, None, Some(('2', '@')), Some(('\'', '"')), None],
    ),
    (
      '2',
      [
        Some(('1', '!')),
        None,
        None,
        Some(('3', '#')),
        Some((',', '<')),
        Some(('\'', '"')),
      ],
    ),
    (
      '3',
      [
        Some(('2', '@')),
        None,
        None,
        Some(('4', '$')),
        Some(('.', '>')),
        Some((',', '<')),
      ],
    ),
    (
      '4',
      [
        Some(('3', '#')),
        None,
        None,
        Some(('5', '%')),
        Some(('p', 'P')),
        Some(('.', '>')),
      ],
    ),
    (
      '5',
      [
        Some(('4', '$')),
        None,
        None,
        Some(('6', '^')),
        Some(('y', 'Y')),
        Some(('p', 'P')),
      ],
    ),
    (
      '6',
      [
        Some(('5', '%')),
        None,
        None,
        Some(('7', '&')),
        Some(('f', 'F')),
        Some(('y', 'Y')),
      ],
    ),
    (
      '7',
      [
        Some(('6', '^')),
        None,
        None,
        Some(('8', '*')),
        Some(('g', 'G')),
        Some(('f', 'F')),
      ],
    ),
    (
      '8',
      [
        Some(('7', '&')),
        None,
        None,
        Some(('9', '(')),
        Some(('c', 'C')),
        Some(('g', 'G')),
      ],
    ),
    (
      '9',
      [
        Some(('8', '*')),
        None,
        None,
        Some(('0', ')')),
        Some(('r', 'R')),
        Some(('c', 'C')),
      ],
    ),
    (
      ':',
      [None, Some(('a', 'A')), Some(('o', 'O')), Some(('q', 'Q')), None, None],
    ),
    (
      ';',
      [None, Some(('a', 'A')), Some(('o', 'O')), Some(('q', 'Q')), None, None],
    ),
    (
      '<',
      [
        Some(('\'', '"')),
        Some(('2', '@')),
        Some(('3', '#')),
        Some(('.', '>')),
        Some(('o', 'O')),
        Some(('a', 'A')),
      ],
    ),
    (
      '=',
      [
        Some(('/', '?')),
        Some((']', '}')),
        None,
        Some(('\\', '|')),
        None,
        Some(('-', '_')),
      ],
    ),
    (
      '>',
      [
        Some((',', '<')),
        Some(('3', '#')),
        Some(('4', '$')),
        Some(('p', 'P')),
        Some(('e', 'E')),
        Some(('o', 'O')),
      ],
    ),
    (
      '?',
      [
        Some(('l', 'L')),
        Some(('[', '{')),
        Some((']', '}')),
        Some(('=', '+')),
        Some(('-', '_')),
        Some(('s', 'S')),
      ],
    ),
    (
      '@',
      [
        Some(('1', '!')),
        None,
        None,
        Some(('3', '#')),
        Some((',', '<')),
        Some(('\'', '"')),
      ],
    ),
    (
      'A',
      [
        None,
        Some(('\'', '"')),
        Some((',', '<')),
        Some(('o', 'O')),
        Some((';', ':')),
        None,
      ],
    ),
    (
      'B',
      [
        Some(('x', 'X')),
        Some(('d', 'D')),
        Some(('h', 'H')),
        Some(('m', 'M')),
        None,
        None,
      ],
    ),
    (
      'C',
      [
        Some(('g', 'G')),
        Some(('8', '*')),
        Some(('9', '(')),
        Some(('r', 'R')),
        Some(('t', 'T')),
        Some(('h', 'H')),
      ],
    ),
    (
      'D',
      [
        Some(('i', 'I')),
        Some(('f', 'F')),
        Some(('g', 'G')),
        Some(('h', 'H')),
        Some(('b', 'B')),
        Some(('x', 'X')),
      ],
    ),
    (
      'E',
      [
        Some(('o', 'O')),
        Some(('.', '>')),
        Some(('p', 'P')),
        Some(('u', 'U')),
        Some(('j', 'J')),
        Some(('q', 'Q')),
      ],
    ),
    (
      'F',
      [
        Some(('y', 'Y')),
        Some(('6', '^')),
        Some(('7', '&')),
        Some(('g', 'G')),
        Some(('d', 'D')),
        Some(('i', 'I')),
      ],
    ),
    (
      'G',
      [
        Some(('f', 'F')),
        Some(('7', '&')),
        Some(('8', '*')),
        Some(('c', 'C')),
        Some(('h', 'H')),
        Some(('d', 'D')),
      ],
    ),
    (
      'H',
      [
        Some(('d', 'D')),
        Some(('g', 'G')),
        Some(('c', 'C')),
        Some(('t', 'T')),
        Some(('m', 'M')),
        Some(('b', 'B')),
      ],
    ),
    (
      'I',
      [
        Some(('u', 'U')),
        Some(('y', 'Y')),
        Some(('f', 'F')),
        Some(('d', 'D')),
        Some(('x', 'X')),
        Some(('k', 'K')),
      ],
    ),
    (
      'J',
      [
        Some(('q', 'Q')),
        Some(('e', 'E')),
        Some(('u', 'U')),
        Some(('k', 'K')),
        None,
        None,
      ],
    ),
    (
      'K',
      [
        Some(('j', 'J')),
        Some(('u', 'U')),
        Some(('i', 'I')),
        Some(('x', 'X')),
        None,
        None,
      ],
    ),
    (
      'L',
      [
        Some(('r', 'R')),
        Some(('0', ')')),
        Some(('[', '{')),
        Some(('/', '?')),
        Some(('s', 'S')),
        Some(('n', 'N')),
      ],
    ),
    (
      'M',
      [
        Some(('b', 'B')),
        Some(('h', 'H')),
        Some(('t', 'T')),
        Some(('w', 'W')),
        None,
        None,
      ],
    ),
    (
      'N',
      [
        Some(('t', 'T')),
        Some(('r', 'R')),
        Some(('l', 'L')),
        Some(('s', 'S')),
        Some(('v', 'V')),
        Some(('w', 'W')),
      ],
    ),
    (
      'O',
      [
        Some(('a', 'A')),
        Some((',', '<')),
        Some(('.', '>')),
        Some(('e', 'E')),
        Some(('q', 'Q')),
        Some((';', ':')),
      ],
    ),
    (
      'P',
      [
        Some(('.', '>')),
        Some(('4', '$')),
        Some(('5', '%')),
        Some(('y', 'Y')),
        Some(('u', 'U')),
        Some(('e', 'E')),
      ],
    ),
    (
      'Q',
      [
        Some((';', ':')),
        Some(('o', 'O')),
        Some(('e', 'E')),
        Some(('j', 'J')),
        None,
        None,
      ],
    ),
    (
      'R',
      [
        Some(('c', 'C')),
        Some(('9', '(')),
        Some(('0', ')')),
        Some(('l', 'L')),
        Some(('n', 'N')),
        Some(('t', 'T')),
      ],
    ),
    (
      'S',
      [
        Some(('n', 'N')),
        Some(('l', 'L')),
        Some(('/', '?')),
        Some(('-', '_')),
        Some(('z', 'Z')),
        Some(('v', 'V')),
      ],
    ),
    (
      'T',
      [
        Some(('h', 'H')),
        Some(('c', 'C')),
        Some(('r', 'R')),
        Some(('n', 'N')),
        Some(('w', 'W')),
        Some(('m', 'M')),
      ],
    ),
    (
      'U',
      [
        Some(('e', 'E')),
        Some(('p', 'P')),
        Some(('y', 'Y')),
        Some(('i', 'I')),
        Some(('k', 'K')),
        Some(('j', 'J')),
      ],
    ),
    (
      'V',
      [
        Some(('w', 'W')),
        Some(('n', 'N')),
        Some(('s', 'S')),
        Some(('z', 'Z')),
        None,
        None,
      ],
    ),
    (
      'W',
      [
        Some(('m', 'M')),
        Some(('t', 'T')),
        Some(('n', 'N')),
        Some(('v', 'V')),
        None,
        None,
      ],
    ),
    (
      'X',
      [
        Some(('k', 'K')),
        Some(('i', 'I')),
        Some(('d', 'D')),
        Some(('b', 'B')),
        None,
        None,
      ],
    ),
    (
      'Y',
      [
        Some(('p', 'P')),
        Some(('5', '%')),
        Some(('6', '^')),
        Some(('f', 'F')),
        Some(('i', 'I')),
        Some(('u', 'U')),
      ],
    ),
    (
      'Z',
      [Some(('v', 'V')), Some(('s', 'S')), Some(('-', '_')), None, None, None],
    ),
    (
      '[',
      [
        Some(('0', ')')),
        None,
        None,
        Some((']', '}')),
        Some(('/', '?')),
        Some(('l', 'L')),
      ],
    ),
    ('\\', [Some(('=', '+')), None, None, None, None, None]),
    (
      ']',
      [Some(('[', '{')), None, None, None, Some(('=', '+')), Some(('/', '?'))],
    ),
    (
      '^',
      [
        Some(('5', '%')),
        None,
        None,
        Some(('7', '&')),
        Some(('f', 'F')),
        Some(('y', 'Y')),
      ],
    ),
    (
      '_',
      [
        Some(('s', 'S')),
        Some(('/', '?')),
        Some(('=', '+')),
        None,
        None,
        Some(('z', 'Z')),
      ],
    ),
    ('`', [None, None, None, Some(('1', '!')), None, None]),
    (
      'a',
      [
        None,
        Some(('\'', '"')),
        Some((',', '<')),
        Some(('o', 'O')),
        Some((';', ':')),
        None,
      ],
    ),
    (
      'b',
      [
        Some(('x', 'X')),
        Some(('d', 'D')),
        Some(('h', 'H')),
        Some(('m', 'M')),
        None,
        None,
      ],
    ),
    (
      'c',
      [
        Some(('g', 'G')),
        Some(('8', '*')),
        Some(('9', '(')),
        Some(('r', 'R')),
        Some(('t', 'T')),
        Some(('h', 'H')),
      ],
    ),
    (
      'd',
      [
        Some(('i', 'I')),
        Some(('f', 'F')),
        Some(('g', 'G')),
        Some(('h', 'H')),
        Some(('b', 'B')),
        Some(('x', 'X')),
      ],
    ),
    (
      'e',
      [
        Some(('o', 'O')),
        Some(('.', '>')),
        Some(('p', 'P')),
        Some(('u', 'U')),
        Some(('j', 'J')),
        Some(('q', 'Q')),
      ],
    ),
    (
      'f',
      [
        Some(('y', 'Y')),
        Some(('6', '^')),
        Some(('7', '&')),
        Some(('g', 'G')),
        Some(('d', 'D')),
        Some(('i', 'I')),
      ],
    ),
    (
      'g',
      [
        Some(('f', 'F')),
        Some(('7', '&')),
        Some(('8', '*')),
        Some(('c', 'C')),
        Some(('h', 'H')),
        Some(('d', 'D')),
      ],
    ),
    (
      'h',
      [
        Some(('d', 'D')),
        Some(('g', 'G')),
        Some(('c', 'C')),
        Some(('t', 'T')),
        Some(('m', 'M')),
        Some(('b', 'B')),
      ],
    ),
    (
      'i',
      [
        Some(('u', 'U')),
        Some(('y', 'Y')),
        Some(('f', 'F')),
        Some(('d', 'D')),
        Some(('x', 'X')),
        Some(('k', 'K')),
      ],
    ),
    (
      'j',
      [
        Some(('q', 'Q')),
        Some(('e', 'E')),
        Some(('u', 'U')),
        Some(('k', 'K')),
        None,
        None,
      ],
    ),
    (
      'k',
      [
        Some(('j', 'J')),
        Some(('u', 'U')),
        Some(('i', 'I')),
        Some(('x', 'X')),
        None,
        None,
      ],
    ),
    (
      'l',
      [
        Some(('r', 'R')),
        Some(('0', ')')),
        Some(('[', '{')),
        Some(('/', '?')),
        Some(('s', 'S')),
        Some(('n', 'N')),
      ],
    ),
    (
      'm',
      [
        Some(('b', 'B')),
        Some(('h', 'H')),
        Some(('t', 'T')),
        Some(('w', 'W')),
        None,
        None,
      ],
    ),
    (
      'n',
      [
        Some(('t', 'T')),
        Some(('r', 'R')),
        Some(('l', 'L')),
        Some(('s', 'S')),
        Some(('v', 'V')),
        Some(('w', 'W')),
      ],
    ),
    (
      'o',
      [
        Some(('a', 'A')),
        Some((',', '<')),
        Some(('.', '>')),
        Some(('e', 'E')),
        Some(('q', 'Q')),
        Some((';', ':')),
      ],
    ),
    (
      'p',
      [
        Some(('.', '>')),
        Some(('4', '$')),
        Some(('5', '%')),
        Some(('y', 'Y')),
        Some(('u', 'U')),
        Some(('e', 'E')),
      ],
    ),
    (
      'q',
      [
        Some((';', ':')),
        Some(('o', 'O')),
        Some(('e', 'E')),
        Some(('j', 'J')),
        None,
        None,
      ],
    ),
    (
      'r',
      [
        Some(('c', 'C')),
        Some(('9', '(')),
        Some(('0', ')')),
        Some(('l', 'L')),
        Some(('n', 'N')),
        Some(('t', 'T')),
      ],
    ),
    (
      's',
      [
        Some(('n', 'N')),
        Some(('l', 'L')),
        Some(('/', '?')),
        Some(('-', '_')),
        Some(('z', 'Z')),
        Some(('v', 'V')),
      ],
    ),
    (
      't',
      [
        Some(('h', 'H')),
        Some(('c', 'C')),
        Some(('r', 'R')),
        Some(('n', 'N')),
        Some(('w', 'W')),
        Some(('m', 'M')),
      ],
    ),
    (
      'u',
      [
        Some(('e', 'E')),
        Some(('p', 'P')),
        Some(('y', 'Y')),
        Some(('i', 'I')),
        Some(('k', 'K')),
        Some(('j', 'J')),
      ],
    ),
    (
      'v',
      [
        Some(('w', 'W')),
        Some(('n', 'N')),
        Some(('s', 'S')),
        Some(('z', 'Z')),
        None,
        None,
      ],
    ),
    (
      'w',
      [
        Some(('m', 'M')),
        Some(('t', 'T')),
        Some(('n', 'N')),
        Some(('v', 'V')),
        None,
        None,
      ],
    ),
    (
      'x',
      [
        Some(('k', 'K')),
        Some(('i', 'I')),
        Some(('d', 'D')),
        Some(('b', 'B')),
        None,
        None,
      ],
    ),
    (
      'y',
      [
        Some(('p', 'P')),
        Some(('5', '%')),
        Some(('6', '^')),
        Some(('f', 'F')),
        Some(('i', 'I')),
        Some(('u', 'U')),
      ],
    ),
    (
      'z',
      [Some(('v', 'V')), Some(('s', 'S')), Some(('-', '_')), None, None, None],
    ),
    (
      '{',
      [
        Some(('0', ')')),
        None,
        None,
        Some((']', '}')),
        Some(('/', '?')),
        Some(('l', 'L')),
      ],
    ),
    ('|', [Some(('=', '+')), None, None, None, None, None]),
    (
      '}',
      [Some(('[', '{')), None, None, None, Some(('=', '+')), Some(('/', '?'))],
    ),
    ('~', [None, None, None, Some(('1', '!')), None, None]),
  ])
})

///|
/// `keypad` 邻接图（上游 `adjacency_graphs.keypad`）。
///
/// 每个条目 `(未移位字符, 移位字符)`；`None` 是该方向没有相邻键。占位的 `None`
/// 必须保留——数组下标即 spatial_match_helper 的 direction 计数。
let keypad : Lazy[Map[Char, Array[(Char, Char)?]]] = Lazy(() => {
  Map([
    (
      '*',
      [
        Some(('/', '/')),
        None,
        None,
        None,
        Some(('-', '-')),
        Some(('+', '+')),
        Some(('9', '9')),
        Some(('8', '8')),
      ],
    ),
    (
      '+',
      [
        Some(('9', '9')),
        Some(('*', '*')),
        Some(('-', '-')),
        None,
        None,
        None,
        None,
        Some(('6', '6')),
      ],
    ),
    (
      '-',
      [
        Some(('*', '*')),
        None,
        None,
        None,
        None,
        None,
        Some(('+', '+')),
        Some(('9', '9')),
      ],
    ),
    (
      '.',
      [
        Some(('0', '0')),
        Some(('2', '2')),
        Some(('3', '3')),
        None,
        None,
        None,
        None,
        None,
      ],
    ),
    (
      '/',
      [
        None,
        None,
        None,
        None,
        Some(('*', '*')),
        Some(('9', '9')),
        Some(('8', '8')),
        Some(('7', '7')),
      ],
    ),
    (
      '0',
      [
        None,
        Some(('1', '1')),
        Some(('2', '2')),
        Some(('3', '3')),
        Some(('.', '.')),
        None,
        None,
        None,
      ],
    ),
    (
      '1',
      [
        None,
        None,
        Some(('4', '4')),
        Some(('5', '5')),
        Some(('2', '2')),
        Some(('0', '0')),
        None,
        None,
      ],
    ),
    (
      '2',
      [
        Some(('1', '1')),
        Some(('4', '4')),
        Some(('5', '5')),
        Some(('6', '6')),
        Some(('3', '3')),
        Some(('.', '.')),
        Some(('0', '0')),
        None,
      ],
    ),
    (
      '3',
      [
        Some(('2', '2')),
        Some(('5', '5')),
        Some(('6', '6')),
        None,
        None,
        None,
        Some(('.', '.')),
        Some(('0', '0')),
      ],
    ),
    (
      '4',
      [
        None,
        None,
        Some(('7', '7')),
        Some(('8', '8')),
        Some(('5', '5')),
        Some(('2', '2')),
        Some(('1', '1')),
        None,
      ],
    ),
    (
      '5',
      [
        Some(('4', '4')),
        Some(('7', '7')),
        Some(('8', '8')),
        Some(('9', '9')),
        Some(('6', '6')),
        Some(('3', '3')),
        Some(('2', '2')),
        Some(('1', '1')),
      ],
    ),
    (
      '6',
      [
        Some(('5', '5')),
        Some(('8', '8')),
        Some(('9', '9')),
        Some(('+', '+')),
        None,
        None,
        Some(('3', '3')),
        Some(('2', '2')),
      ],
    ),
    (
      '7',
      [
        None,
        None,
        None,
        Some(('/', '/')),
        Some(('8', '8')),
        Some(('5', '5')),
        Some(('4', '4')),
        None,
      ],
    ),
    (
      '8',
      [
        Some(('7', '7')),
        None,
        Some(('/', '/')),
        Some(('*', '*')),
        Some(('9', '9')),
        Some(('6', '6')),
        Some(('5', '5')),
        Some(('4', '4')),
      ],
    ),
    (
      '9',
      [
        Some(('8', '8')),
        Some(('/', '/')),
        Some(('*', '*')),
        Some(('-', '-')),
        Some(('+', '+')),
        None,
        Some(('6', '6')),
        Some(('5', '5')),
      ],
    ),
  ])
})

///|
/// `mac_keypad` 邻接图（上游 `adjacency_graphs.mac_keypad`）。
///
/// 每个条目 `(未移位字符, 移位字符)`；`None` 是该方向没有相邻键。占位的 `None`
/// 必须保留——数组下标即 spatial_match_helper 的 direction 计数。
let mac_keypad : Lazy[Map[Char, Array[(Char, Char)?]]] = Lazy(() => {
  Map([
    (
      '*',
      [
        Some(('/', '/')),
        None,
        None,
        None,
        None,
        None,
        Some(('-', '-')),
        Some(('9', '9')),
      ],
    ),
    (
      '+',
      [
        Some(('6', '6')),
        Some(('9', '9')),
        Some(('-', '-')),
        None,
        None,
        None,
        None,
        Some(('3', '3')),
      ],
    ),
    (
      '-',
      [
        Some(('9', '9')),
        Some(('/', '/')),
        Some(('*', '*')),
        None,
        None,
        None,
        Some(('+', '+')),
        Some(('6', '6')),
      ],
    ),
    (
      '.',
      [
        Some(('0', '0')),
        Some(('2', '2')),
        Some(('3', '3')),
        None,
        None,
        None,
        None,
        None,
      ],
    ),
    (
      '/',
      [
        Some(('=', '=')),
        None,
        None,
        None,
        Some(('*', '*')),
        Some(('-', '-')),
        Some(('9', '9')),
        Some(('8', '8')),
      ],
    ),
    (
      '0',
      [
        None,
        Some(('1', '1')),
        Some(('2', '2')),
        Some(('3', '3')),
        Some(('.', '.')),
        None,
        None,
        None,
      ],
    ),
    (
      '1',
      [
        None,
        None,
        Some(('4', '4')),
        Some(('5', '5')),
        Some(('2', '2')),
        Some(('0', '0')),
        None,
        None,
      ],
    ),
    (
      '2',
      [
        Some(('1', '1')),
        Some(('4', '4')),
        Some(('5', '5')),
        Some(('6', '6')),
        Some(('3', '3')),
        Some(('.', '.')),
        Some(('0', '0')),
        None,
      ],
    ),
    (
      '3',
      [
        Some(('2', '2')),
        Some(('5', '5')),
        Some(('6', '6')),
        Some(('+', '+')),
        None,
        None,
        Some(('.', '.')),
        Some(('0', '0')),
      ],
    ),
    (
      '4',
      [
        None,
        None,
        Some(('7', '7')),
        Some(('8', '8')),
        Some(('5', '5')),
        Some(('2', '2')),
        Some(('1', '1')),
        None,
      ],
    ),
    (
      '5',
      [
        Some(('4', '4')),
        Some(('7', '7')),
        Some(('8', '8')),
        Some(('9', '9')),
        Some(('6', '6')),
        Some(('3', '3')),
        Some(('2', '2')),
        Some(('1', '1')),
      ],
    ),
    (
      '6',
      [
        Some(('5', '5')),
        Some(('8', '8')),
        Some(('9', '9')),
        Some(('-', '-')),
        Some(('+', '+')),
        None,
        Some(('3', '3')),
        Some(('2', '2')),
      ],
    ),
    (
      '7',
      [
        None,
        None,
        None,
        Some(('=', '=')),
        Some(('8', '8')),
        Some(('5', '5')),
        Some(('4', '4')),
        None,
      ],
    ),
    (
      '8',
      [
        Some(('7', '7')),
        None,
        Some(('=', '=')),
        Some(('/', '/')),
        Some(('9', '9')),
        Some(('6', '6')),
        Some(('5', '5')),
        Some(('4', '4')),
      ],
    ),
    (
      '9',
      [
        Some(('8', '8')),
        Some(('=', '=')),
        Some(('/', '/')),
        Some(('*', '*')),
        Some(('-', '-')),
        Some(('+', '+')),
        Some(('6', '6')),
        Some(('5', '5')),
      ],
    ),
    (
      '=',
      [
        None,
        None,
        None,
        None,
        Some(('/', '/')),
        Some(('9', '9')),
        Some(('8', '8')),
        Some(('7', '7')),
      ],
    ),
  ])
})

///|
/// 邻接图的平均度数（上游 `calc_average_degree`）。
///
/// 注意：上游 CoffeeScript 用的是**浮点除法**（432/94 = 4.595744680851064），
/// 而 zxcvbn-rs 用 u64 整数除法（= 4）。本项目以 dropbox/zxcvbn 官方向量为基准，
/// 故沿用浮点语义——差分对拍时若要跟 zxcvbn-rs 比，这里必须有意识地记为差异点。
fn calc_average_degree(graph : Map[Char, Array[(Char, Char)?]]) -> Double {
  let mut sum = 0
  for arcs in graph.values() {
    for arc in arcs {
      match arc {
        Some(_) => sum += 1
        None => ()
      }
    }
  }
  sum.to_double() / graph.length().to_double()
}

///|
/// qwerty/dvorak 用的起始键位数。
pub let keyboard_starting_positions : Int = qwerty.force().length()

///|
/// keypad/mac_keypad 用的起始键位数。
pub let keypad_starting_positions : Int = keypad.force().length()

///|
/// qwerty/dvorak 的平均度数。
pub let keyboard_average_degree : Double = calc_average_degree(qwerty.force())

///|
/// keypad/mac_keypad 的平均度数（上游注释：与 qwerty 略有不同，但取近似值）。
pub let keypad_average_degree : Double = calc_average_degree(keypad.force())

///|
/// 按图名取邻接图（spatial_match 的四个图）。图名与上游一致。
pub fn get_graph(name : String) -> Map[Char, Array[(Char, Char)?]] {
  match name {
    "qwerty" => qwerty.force()
    "dvorak" => dvorak.force()
    "keypad" => keypad.force()
    "mac_keypad" => mac_keypad.force()
    _ => abort("unknown adjacency graph: \{name}")
  }
}

///|
/// 四个键盘图的名字（顺序与上游 GRAPHS 一致，决定 omnimatch 的匹配顺序）。
pub let graph_names : Array[String] = [
  "qwerty", "dvorak", "keypad", "mac_keypad",
]
