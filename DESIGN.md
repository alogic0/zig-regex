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

The initial package targets the pinned Zig 0.17.0 toolchain. Migrating the
0.15.2 CLI requires separate compatibility work; adding this provider does not
silently migrate that compiler or change existing consumers' matching semantics.
The optional SIMD prefilter remains disabled, matching the extraction source.

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

Provider unit tests, a separate package caller, a native example and a Wasm
caller establish distinct boundaries. They do not replace consumer acceptance.
For every adoption, exercise the consumer's existing diagnostics, empty matches,
Unicode/capture offsets and configured limits, and compile its actual target.
