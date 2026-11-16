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
    var boundary = regex.compileRe(allocator, "\\b(Shape)\\b|shape ==|shape !=", .{}) catch return 11;
    defer boundary.deinit();
    const isolated = (boundary.firstMatch("éShape Shape") catch return 12) orelse return 13;
    defer isolated.deinit(allocator);
    if (isolated.span.start != 8 or isolated.span.end != 13) return 14;
    if (isolated.groups[0].start != 8 or isolated.groups[0].end != 13) return 15;
    const raw = (boundary.firstMatchBytes("\xffShape\xff") catch return 16) orelse return 17;
    defer raw.deinit(allocator);
    if (raw.span.start != 1 or raw.span.end != 6) return 18;
    return 0;
}
