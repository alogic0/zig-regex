const std = @import("std");
const regex = @import("regex");

test "package import preserves byte spans, captures and instruction admission" {
    var compiled = try regex.compileRe(std.testing.allocator, "(σ+)", .{
        .case_insensitive = true,
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
}
