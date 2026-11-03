const std = @import("std");
const regex = @import("regex");

/// Returns zero when the freestanding target exercises the public API correctly.
export fn regexAcceptance() u32 {
    const allocator = std.heap.wasm_allocator;
    var compiled = regex.compileRe(allocator, "(?i)(σ+)-([0-9]+)", .{
        .max_instructions = 4096,
    }) catch return 1;
    defer compiled.deinit();
    const found = (compiled.firstMatch("ΣΣ-42") catch return 2) orelse return 3;
    defer found.deinit(allocator);
    if (found.span.start != 0 or found.span.end != 7 or found.groups.len != 2) return 4;
    if (found.groups[0].start != 0 or found.groups[0].end != 4) return 5;
    if (!(compiled.isMatch("σ-7") catch return 6)) return 7;
    var selected = regex.compileRe(allocator, "x", .{ .simd_prefilter = true }) catch return 8;
    defer selected.deinit();
    if (!(selected.isMatch("aaaaaaaaaaaaaaaaax") catch return 9)) return 10;
    return 0;
}
