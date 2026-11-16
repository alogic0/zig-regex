const std = @import("std");
const regex = @import("regex");

test "package boundary searches preserve Unicode context captures and invalid bytes" {
    const allocator = std.testing.allocator;
    var compiled = try regex.compileRe(allocator, "\\b(Shape)\\b|shape ==|shape !=", .{});
    defer compiled.deinit();
    try std.testing.expect(!(try compiled.isMatch("xxxxxxxxxxxxxxxxxxxxxxxx")));
    const found = (try compiled.firstMatch("éShape Shape")).?;
    defer found.deinit(allocator);
    try std.testing.expectEqual(regex.Capture{ .start = 8, .end = 13 }, found.span);
    try std.testing.expectEqual(found.span, found.groups[0]);
    const raw = (try compiled.firstMatchBytes("\xffShape\xff")).?;
    defer raw.deinit(allocator);
    try std.testing.expectEqual(regex.Capture{ .start = 1, .end = 6 }, raw.span);
}

test "package import preserves byte spans, captures and instruction admission" {
    var compiled = try regex.compileRe(std.testing.allocator, "(?i)(σ+)", .{
        .max_instructions = 4096,
    });
    defer compiled.deinit();
    const found = (try compiled.firstMatch("ΣΣ")).?;
    defer found.deinit(std.testing.allocator);
    try std.testing.expectEqual(regex.Capture{ .start = 0, .end = 4 }, found.span);
    try std.testing.expectEqual(found.span, found.groups[0]);
    try std.testing.expectError(error.ProgramTooLarge, regex.compileRe(std.testing.allocator, "a{5000}", .{
        .max_instructions = 4096,
    }));
    var selected = try regex.compileRe(std.testing.allocator, "x", .{ .simd_prefilter = true });
    defer selected.deinit();
    try std.testing.expect(selected.program.prefilter.?.simd_prefilter);
    try std.testing.expect(try selected.isMatch("aaaaaaaaaaaaaaaaax"));
}
