const std = @import("std");
const regex = @import("regex/root.zig");

test "vendored regex matches validation patterns" {
    var compiled = try regex.compileRe(std.testing.allocator, "[A-Za-z]+\\s+needle$", .{});
    defer compiled.deinit();

    try std.testing.expect(try compiled.isMatch("local needle"));
    try std.testing.expect(!try compiled.isMatch("local needle extra"));
}
