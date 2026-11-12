# zig-regex

Dependency-free regex library for Zig with Unicode support, captures, byte
offsets, and explicit allocator ownership.

Version **0.2.1** supports Zig **0.17.0** and **0.15.2**. The package exports one
module, `regex`, which has no package, C-library or IO dependencies. Generated
Unicode data is included; normal builds do not download anything.

- Unicode properties and simple case folding, including scoped inline modes.
- Named and numbered captures with offsets into the original input bytes.
- Greedy and lazy repetition, character classes, anchors and word boundaries.
- UTF-8 matching and a separate entry point for input containing invalid bytes.
- Caller-supplied allocation and an optional compiled-instruction limit.

This is a pre-1.0 regex subset. Lookaround and backreferences are unsupported;
it does not claim PCRE compatibility. See [syntax and limits](#syntax-and-limits)
before choosing it for an existing pattern set.

## Try it

From a checkout, with the compiler pinned in [`.zigversion`](.zigversion):

```sh
zig build example
zig build test check
```

The [complete example](examples/basic.zig) compiles a pattern, extracts a capture
and releases the compiled pattern and match. The example prints `capture: 42`.

## Use

Download the release's `zig-regex-0.2.1.tar.gz`, `SHA256SUMS` and
`PACKAGE_INFO.txt` together. In the download directory, verify the archive:

```sh
sha256sum --check SHA256SUMS
```

Copy the archive to your project's `vendor/` directory, then run from your
project root:

```sh
zig fetch vendor/zig-regex-0.2.1.tar.gz
```

Compare the printed hash with `PACKAGE_INFO.txt`, which also records the source
revision. Add a `.regex` entry to `build.zig.zon` dependencies with
`.url = "file:vendor/zig-regex-0.2.1.tar.gz"` and `.hash` set to that verified
hash. Use a filesystem path for the fetch command: relative `file:` URLs resolve
correctly in dependency manifests, but direct fetch handling differs between
the qualified compilers. Commit the archive and manifest together.
For a local checkout next to your project, add this entry to the existing
`.dependencies` in `build.zig.zon`:

```zig
.regex = .{ .path = "../zig-regex" },
```

Wire the public module into your `build.zig`, where `exe` is your executable:

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

The optional `.simd_prefilter = true` compilation setting enables the inherited
single-byte literal scan on supported native architectures. It defaults to false
and is stored per compiled program; there is no application build option or
global switch inside the package. Other targets use the generic scan.

`max_instructions` bounds emitted NFA instructions and rejects oversized counted
repetition before expansion. It does not bound pattern bytes, parser nesting,
haystack size or total matching time. Consumers must choose their own admission
and workload limits. See [DESIGN.md](DESIGN.md) for ownership and compatibility.

## Check

Use the default compiler in [`.zigversion`](.zigversion). Repeat with the exact
Zig 0.15.2 executable when checking its supported compatibility boundary:

```sh
zig build test check example --summary all
zig build test check example -Doptimize=ReleaseSafe --summary all
zig build test-wasm --summary all
zig build test-wasm -Doptimize=ReleaseSafe --summary all
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
`test-wasm` executes that export using Node.js (18 or newer); Node is a test-host
dependency and is not required to compile or use the library.
The isolated package caller checks that users need no private source imports.

The qualification targets are Linux x86_64 and freestanding Wasm on Zig 0.15.2
and 0.17.0. Other native platforms and Zig 0.16 remain unqualified.
See [NOTICE](NOTICE) for
source provenance. Code uses [MIT](LICENSE); generated Unicode data uses
[Unicode License V3](UNICODE-LICENSE).

## Contributing and releases

Use the GitHub issue templates to report a reproducible bug or propose a change.
See [CONTRIBUTING.md](CONTRIBUTING.md) for ownership and regression expectations,
[CHANGELOG.md](CHANGELOG.md) for version history and [RELEASING.md](RELEASING.md)
for GitHub setup and reproducible source distribution. CI checks Debug and
ReleaseSafe, native and Wasm callers, archived sources, and archive dependencies
with empty caches before retaining distribution artifacts.

Release tooling uses a pinned, vendored copy of `zig-package-version` under
[tools/vendor/zig-package-version](tools/vendor/zig-package-version/UPSTREAM).
It requires Zig 0.17.0 and synchronizes the manifest and README versions through
[versions.zon](versions.zon). See [version management](RELEASING.md#version-management)
for the commands. Regex consumers do not compile this tool.
