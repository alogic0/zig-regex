# Changelog

## 0.2.0 — 2026-11-03

- Qualify the pure regex core on Zig 0.15.2 alongside the default Zig 0.17.0,
  using portable enum-conversion aliases and retaining consumer-owned CLI/IO.
- Exercise native, Wasm and independent package callers on both compilers.
- Expose the inherited SIMD literal prefilter as a per-compilation opt-in,
  retaining the disabled default and keeping application build options outside
  the library.
- Use filesystem paths in the archive-fetch instructions; retain relative
  `file:` URLs in dependency manifests and verify consumer builds from an empty
  global cache.

## 0.1.0 — 2026-11-03

- Extract the allocator-owned parser/HIR/NFA/VM/DFA and Unicode tables into an
  independent Zig 0.17.0 package with the public `regex` module.
- Preserve captures, byte offsets, raw-byte matching, instruction admission and
  scoped case modes; keep search/replacement and IO policy with consumers.
- Repair inherited partial-construction and allocation-failure cleanup, including
  named captures, scoped folding, NFA/VM state and literal prefilters.
- Honor inline `(?i)` with the global case-folding default off while preserving
  nested disabling scopes and ordinary literal-prefilter behavior.
- Include native and freestanding Wasm callers, an independent package fixture,
  Debug/ReleaseSafe CI and reproducible source-distribution tooling.
- Retain the original MIT and Unicode notices and extraction provenance.
