# Contributing

Use the exact compiler in `.zigversion` and read `DESIGN.md` before changing
matching behavior or the public API. Keep allocation ownership, byte offsets and
the consumer/package boundary explicit. IO, search iteration, replacement syntax
and application admission policy belong to callers.

For a bug report, include the pattern, input, options, expected match/capture
byte offsets, actual result and Zig version. Reduce confidential input before
sharing it. Add a focused regression for a behavior correction; use the testing
allocator and allocation-failure checks for ownership changes. Preserve the MIT
and Unicode notices and record any regenerated Unicode data's source version.

Use the bug-report form for failures and the feature-request form for proposals.
Explain a proposed feature's use case and how it fits the library boundary in
`DESIGN.md`. Open pull requests against `main` with the problem, resulting
behavior and the checks actually run. Distinguish target compilation from
execution on that target.

Before proposing a change:

```sh
zig fmt --check build.zig build.zig.zon versions.zon src examples tests tools
zig build test check example test-wasm --summary all
zig build test check example test-wasm -Doptimize=ReleaseSafe --summary all
cd tests/package
zig build test --summary all
zig build test -Doptimize=ReleaseSafe --summary all
cd ../..
git diff --check
```

Repeat the provider, Wasm and package checks with the exact Zig 0.15.2 executable
for changes in the compatibility core. The default formatter remains 0.17.0;
preserve the narrow enum-alias formatter guard in `src/compat.zig`.
Wasm execution uses Node.js 18 or newer. Compiler-only `check` needs no Node.
Keep fixes separate from source moves and new syntax. The initial qualified
targets are Linux x86_64 and freestanding Wasm on both qualified compilers;
additional platforms need actual
target runtime evidence. For packaging changes, also run the archive-consumer
check in [RELEASING.md](RELEASING.md) on both supported compilers.

Version tooling uses the pinned Zig 0.17.0 compiler. For changes to its wrapper,
configuration or vendored sources, run these checks from the repository root:

```sh
(cd tools/vendor/zig-package-version && sha256sum --check SHA256SUMS)
mkdir -p zig-out
for optimize in Debug ReleaseSafe; do
  zig build-exe tools/package_version.zig -O"$optimize" -femit-bin=zig-out/package-version
  zig-out/package-version get
  node tests/package-version.mjs zig-out/package-version
done
```

The setter tests use disposable copies of project files. Keep the upstream
snapshot byte-for-byte intact; update its `UPSTREAM` receipt and `SHA256SUMS`
when adopting a new verified commit. Project-specific markers belong in
`versions.zon`; historical changelog entries are edited separately.
