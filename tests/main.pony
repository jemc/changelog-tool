use "files"
use "ponytest"
use ".."
use "../.deps/sylvanc/peg"

actor Main is TestList
  new create(env: Env) => PonyTest(env, this)

  fun tag tests(test: PonyTest) =>
    //test(_TestParseVersion)
    //test(_TestParseDate)
    //test(_TestParseEntry)
    test(_TestParseChangelog)

class ParseTest
  let _h: TestHelper
  let _parser: Parser

  new create(h: TestHelper, parser: Parser) =>
    (_h, _parser) = (h, parser)

  fun run(tests: Array[(String, String)]) =>
    for (source, expected) in tests.values() do
      _h.log("test: " + source)
      match _parser.parse(source)
      | (_, let r: (AST | Token | NotPresent)) =>
        let result = recover val Printer(r) end
        _h.assert_eq[String](expected, result)
      | (let offset: USize, let r: Parser) =>
        _h.log(String.join(Error("", source, offset, r)))
        _h.assert_eq[String](expected, "")
      | (_, Skipped) => _h.log("skipped")
      | (_, Lex) => _h.log("lex")
      end
    end

class iso _TestParseVersion is UnitTest
  fun name(): String => "parse version"

  fun apply(h: TestHelper) =>
    ParseTest(h, ChangelogParser.version()).run([
      ("0.0.0", "(Version 0.0.0)\n")
      ("1.23.9", "(Version 1.23.9)\n")
      ("0..0", "")
      (".0.0", "")
      ("0..", "")
      ("0", "")
    ])

class iso _TestParseDate is UnitTest
  fun name(): String => "parse date"

  fun apply(h: TestHelper) =>
    ParseTest(h, ChangelogParser.date()).run([
      ("2017-04-07", "(Date 2017-04-07)\n")
      ("0000-00-00", "(Date 0000-00-00)\n")
      ("0000-00-0", "")
      ("0000-0-00", "")
      ("000-00-00", "")
      ("00-0000-00", "")
    ])

class iso _TestParseEntry is UnitTest
  fun name(): String => "parse entry"

  fun apply(h: TestHelper) =>
    ParseTest(h, ChangelogParser.entry()).run([
      ("32-bit ARM port.", "")
      ("- 32-bit ARM port.", "(Entry - 32-bit ARM port.)\n")
      ("- abc\n  - def\n\n", "(Entry - abc\n  - def)\n")
      ( """
        - abc
          - def
            - ghi
          - jkl
        """,
        "(Entry - abc\n  - def\n    - ghi\n  - jkl)\n")
      ("- @fowles: handle regex empty match.",
        "(Entry - @fowles: handle regex empty match.)\n")
      ("- Upgrade to LLVM 3.9.1 ([PR #1498](https://github.com/ponylang/ponyc/pull/1498))",
        "(Entry - Upgrade to LLVM 3.9.1 ([PR #1498](https://github.com/ponylang/ponyc/pull/1498)))\n")
    ])

class iso _TestParseChangelog is UnitTest
  fun name(): String => "parse CHANGELOG"

  fun apply(h: TestHelper) ? =>
    let p = ChangelogParser().eof()
    let testfile = "CHANGELOG.md"

    with file = OpenFile(
      FilePath(h.env.root as AmbientAuth, testfile)) as File
    do
      let source: String = file.read_string(file.size())
      match p.parse(source)
      | (let n: USize, let r: (AST | Token | NotPresent)) =>
        h.assert_eq[USize](28782, n)
        h.log(recover val Printer(r) end)
      | (let offset: USize, let r: Parser) =>
        h.log(String.join(Error(testfile, source, offset, r)))
        h.fail()
      end
    end
