# Bound preceding-text lookup for word assertions

The zigrep consumer exposes a confirmed scaling defect in zig-regex 0.2.2.
Searching `\bShape\b|shape ==|shape !=` over N ASCII `x` bytes takes roughly
four times as long when N doubles: installed ReleaseFast consumer measurements
are 0.03 s at 4 KiB, 0.13 s at 8 KiB and 0.51 s at 16 KiB. A private 69,988-byte
source workload times out at five seconds, while rg returns no match promptly.
Only synthetic input belongs in committed tests.

`wordBoundaryAt` and `wordBoundaryStartHalfAt` restart `nextTextUnit` at zero
for each asserted position. Unanchored VM restarts therefore rescan prefixes
quadratically. Replace that prefix scan with bounded local UTF-8 context lookup.
Retain the existing classification of valid Unicode, ASCII-only boundaries,
individual invalid bytes, and positions inside valid multi-byte sequences.
Do not change public matching policy, captures, allocation ownership or offsets.

Before adoption, compare native results with the existing forward-decoding
definition across ASCII, valid two/three/four-byte sequences and malformed
UTF-8. Cover ordinary, negative and half-boundaries, offset-based matching,
no-hit and late-hit searches, and raw-byte entry points. Keep timing thresholds
out of unit tests. Run the pinned Zig 0.17.0 Debug/ReleaseSafe test/check,
native/Wasm and package-caller checks required by the repository, qualify a
clean committed source archive, then let zigrep adopt its exact hash and qualify
the actual installed ReleaseFast CLI. Private source remains with its caller.

The 0.2.3 fix decodes bounded preceding context and preserves the old forward
decoder's classification, including offsets inside valid multi-byte units.
Regression coverage compares every two-byte input and mixed valid/malformed
UTF-8 triples, both Unicode and ASCII-only assertions, all boundary halves,
growing misses and late captures, and raw-byte/public package entry points.
Native Debug and ReleaseSafe each pass 120/120 provider tests, the native
example, and actual Wasm execution. The public package caller is checked in
both modes before the committed source archive is qualified for adoption.
