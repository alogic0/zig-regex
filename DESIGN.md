# Regex core boundary

## Ownership and API

The public module root is `src/root.zig`. Prefer `compileRe`, `Compiled`,
`CompileOptions`, `Match`, `Capture` and `MatchError`. Low-level parser/HIR/NFA,
Unicode, literal-prefilter and engine aliases preserve the source API for
callers that need diagnostics or offset-based matching. Their data layouts are
pre-1.0 implementation surfaces; consumers should not mutate a compiled program.

Every owned allocation uses the supplied allocator. A `Compiled` and each
returned `Match` have independent release obligations. No IO, process, global
application state, implicit allocator or search/replacement workflow belongs in
this package. The caller controls input admission and iteration. Empty-match
iteration must advance a complete UTF-8 scalar or stop at end of input.

## Extraction baseline

The first source is the independently licensed `src/zigrep_regex` subtree of
Zig Markdown Viewer at `3ed583ed97c2ab77a3bcff95361d49c86b0e5f5f`.
The subtree originated in zigrep at the related source line represented by
`bcd812c9a1e7fe51d2eff5fa345f0ed420cde8c0`. This extraction preserves the
existing algorithm and source tests rather than combining divergent engines.

Comparison with the other inventoried copies found:

- The Zig 0.15.2 CLI and compiler-tool copy lack the global case-insensitive
  option, instruction admission and later greedy-capture/offset handling.
  Their literal prefilter also uses application build options.
- The frontend-tooling and backend copies match this variant's functionality;
  observed parser/HIR/Unicode differences are enum-conversion spellings.
- Generated Unicode-table differences are formatting changes in empty arrays.

The initial package targeted the pinned Zig 0.17.0 toolchain. Version 0.2.0
also qualifies the pure core on Zig 0.15.2 so a consumer can retain its existing
CLI/IO toolchain. `compat.zig` isolates enum-conversion aliases understood by
both compilers; its narrow formatter guard prevents the default formatter from
renaming them into 0.17-only syntax. No application or runtime dependency is
introduced. The native example uses an explicit allocator and portable entrypoint.
The optional SIMD prefilter remains disabled by default, matching the extraction
source. A per-compilation `simd_prefilter` choice preserves an existing caller's
opt-in behavior without importing application build options into the provider.
It is retained on the owned prefilter and passed through both public compilation
and the low-level NFA options. Native vector and tail boundaries have equivalent
generic/opt-in tests; other target architectures keep the generic path.

## Maintenance surface

One independent package replaces a consumer's private copy. The first slice
moves 13 existing Zig files (including generated data) and retains their tests;
the new production layer is the build graph, public aliases and small examples.
No schema, process, service, runtime package dependency or global policy is added.
Consumer integration changes dependency/module wiring and removes the replaced
subtree. Correctness fixes, if required by focused checks, must be recorded
separately from the source relocation.

The follow-up allocation-failure test exposed inherited double-free and leak
paths during parser/HIR/NFA construction and VM thread admission. The revised
surface adds about 100 logical lines of ownership cleanup across the existing
owners, with no new runtime subsystem. Partially built node/instruction payloads,
capture names, patch lists, class expressions and cloned VM slots now have a
single cleanup owner; case folding prepares a replacement before changing a
union tag. Fault injection covers every allocation in named/unnamed capture,
case-fold, literal/DFA, bounded repetition, class-set and raw-byte scenarios.
These error-path repairs are kept in a separate commit from the extraction.

A public-API regression also exposed that inline `(?i)` was ignored when global
case folding was off. Compilation now runs scoped folding when an inline group
enables it, using the global option only as the initial default. Patterns with
neither global nor inline folding keep their existing literal-prefilter path.
This semantic correction has its own provider and consumer regression tests.

## Unicode data

`src/regex/unicode_props_generated.zig` contains the inherited checked-in tables.
Its header records source inputs and `tools/gen_unicode_props.zig` in the source
zigrep repository. The source data came from `zg` at
`6ee2b0719052040c979ecde02a74a0cee6253364`, whose version file names Unicode
16.0.0. This package does not regenerate or upgrade those tables during builds.
The original data license is distributed as `UNICODE-LICENSE`. Regenerating
tables or porting the older generator to a new compiler is separate work and
must preserve a recorded data revision and compare generated behavior.

## Verification scope

Release version synchronization is a development dependency: an unmodified
`zig-package-version` snapshot under `tools/vendor`, pinned by revision and
SHA-256 receipts. The wrapper runs with Zig 0.17.0; `versions.zon` owns this
repository's file and marker choices. It checks release metadata without
joining the regex module's build graph or its Zig 0.15.2 compatibility boundary.
Archive preparation rejects mismatched current versions, and setter acceptance
tests run only in disposable directories.

Provider unit tests, a separate package caller, a native example and a Wasm
caller establish distinct boundaries. They do not replace consumer acceptance.
For every adoption, exercise the consumer's existing diagnostics, empty matches,
Unicode/capture offsets and configured limits, and compile its actual target.
