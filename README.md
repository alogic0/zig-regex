# zig-regex

Allocator-owned regular expressions for Zig **0.17.0**, with Unicode properties,
simple case folding, captures and byte offsets. Version **0.1.0**. The package
exports one module, `regex`, and has no package, C-library or IO dependencies.
Generated Unicode data is included; normal builds do not download anything.

## Use

Add `.regex = .{ .path = "../zig-regex" }` to your package dependencies, then:

```zig
const regex = b.dependency("regex", .{ .target = target, .optimize = optimize });
exe.root_module.addImport("regex", regex.module("regex"));
```

```zig
const regex = @import("regex");

var compiled = try regex.compileRe(allocator, "([a-z]+)-([0-9]+)", .{
    .max_instructions = 4096,
});
defer compiled.deinit();

if (try compiled.firstMatch("item-42")) |found| {
    defer found.deinit(allocator);
    // found.span is 0..7; found.groups[1] is 5..7, in bytes.
}
```

`Compiled` owns the parsed/lowered data and program. Release it once; do not
copy an owner and deinitialize both copies. Compilation does not retain the
pattern. `firstMatch` and `firstMatchBytes` return separately owned capture
arrays; release each match with the same allocator used to compile. Matches
contain numeric offsets, not borrowed text. Keep the original haystack when
using offsets to obtain slices. Optional groups have null start/end offsets.

`isMatch` returns a Boolean. `firstMatch` decodes UTF-8; `firstMatchBytes` can
search input containing invalid bytes without replacing the original bytes.
The low-level `compiled.engine.firstMatchFrom(compiled.program, text, offset)`
retains document-relative anchors while starting a search at a UTF-8 boundary.
Offsets inside a continuation byte are rejected. Matches are leftmost, with
greedy/lazy quantifier priority preserved. Callers own iteration, including
advancing past empty matches, and substitution syntax.

## Syntax and limits

The tested subset includes literals, alternation, capturing/noncapturing/named
groups, greedy/lazy and counted repetition, anchors, word boundaries, character
classes, Unicode properties, class subtraction/intersection and inline `i/u/m/s`
modes. Lookaround and backreferences are unsupported. This is a regex subset,
with its own behavior contract; it does not claim PCRE compatibility.

`CompileOptions` selects multiline admission, dot-all, global simple case
folding and an optional instruction limit. Newline-matching patterns require
`.multiline = true`; `.multiline_dotall` controls unscoped dot matching. Inline
scope choices remain in the parsed expression. The lower-level `compile` only
parses/lowers to owned HIR; its options do not apply the global compile settings.

`max_instructions` bounds emitted NFA instructions and rejects oversized counted
repetition before expansion. It does not bound pattern bytes, parser nesting,
haystack size or total matching time. Consumers must choose their own admission
and workload limits. See [DESIGN.md](DESIGN.md) for ownership and compatibility.

## Check

Use the compiler in [`.zigversion`](.zigversion):

```sh
zig build test check example --summary all
zig build test check example -Doptimize=ReleaseSafe --summary all
zig build test -Dtest-filter=Unicode --summary all
cd tests/package
zig build test --summary all
zig build test -Doptimize=ReleaseSafe --summary all
```

`test` runs the original core regressions, rejected-syntax cleanup and allocation
failure checks through the package root. `check`
compiles the native example and a freestanding Wasm caller, installing the
latter at `zig-out/bin/regex-check.wasm`; its `regexAcceptance()` export returns
zero on success. Compilation alone does not establish target runtime support.
The isolated package caller checks that users need no private source imports.

The initial qualification target is Linux x86_64 and freestanding Wasm. Other
native platforms and Zig 0.15/0.16 remain unqualified. See [NOTICE](NOTICE) for
source provenance. Code uses [MIT](LICENSE); generated Unicode data uses
[Unicode License V3](UNICODE-LICENSE).
