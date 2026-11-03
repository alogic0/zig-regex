const std = @import("std");
const regex = @import("regex");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var compiled = try regex.compileRe(allocator, "([a-z]+)-([0-9]+)", .{
        .max_instructions = 4096,
    });
    defer compiled.deinit();

    const text = "item-42";
    const found = (try compiled.firstMatch(text)) orelse return error.MissingMatch;
    defer found.deinit(allocator);
    if (found.groups.len != 2) return error.UnexpectedCaptureCount;
    const number = found.groups[1];
    if (!std.mem.eql(u8, text[number.start.?..number.end.?], "42")) return error.UnexpectedCapture;
    std.debug.print("capture: {s}\n", .{text[number.start.?..number.end.?]});
}
