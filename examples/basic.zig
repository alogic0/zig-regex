const std = @import("std");
const regex = @import("regex");

pub fn main(init: std.process.Init) !void {
    var compiled = try regex.compileRe(init.gpa, "([a-z]+)-([0-9]+)", .{
        .max_instructions = 4096,
    });
    defer compiled.deinit();

    const text = "item-42";
    const found = (try compiled.firstMatch(text)) orelse return error.MissingMatch;
    defer found.deinit(init.gpa);
    if (found.groups.len != 2) return error.UnexpectedCaptureCount;
    const number = found.groups[1];
    if (!std.mem.eql(u8, text[number.start.?..number.end.?], "42")) return error.UnexpectedCapture;
    var buffer: [128]u8 = undefined;
    var output = std.Io.File.stdout().writer(init.io, &buffer);
    try output.interface.print("capture: {s}\n", .{text[number.start.?..number.end.?]});
    try output.interface.flush();
}
