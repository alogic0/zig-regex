# Working on zig-regex

Use the compiler pinned in `.zigversion`. Keep this an independent repository.
Zig 0.17.0 is the minimum; do not add support or checks for older Zig releases.
Read `DESIGN.md` before changing the public API or matching semantics.
The library owns parsing, compilation and matching; consumers own search loops,
input admission, replacement syntax, IO and application policy.

Preserve allocation ownership and byte-offset semantics. Add focused regression
tests for behavior changes. Format touched Zig files, run `zig build test check`
in Debug and ReleaseSafe, check the package consumer, and run `git diff --check`.
Record checks actually run; compilation is distinct from target runtime checks.

Commit each verified slice separately. Write the complete commit message into a
temporary file and use `git commit -F`; remove the file afterward with plain
`rm -- path`. Do not push or publish unless requested.
