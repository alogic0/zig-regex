//! Enum conversions shared by the qualified 0.15.2 and 0.17.0 compilers.
const std = @import("std");
// The default formatter renames these portable aliases to 0.17-only builtins.
// zig fmt: off
pub inline fn backingInt(value: anytype) std.meta.Tag(@TypeOf(value)) {
    return @intFromEnum(value);
}
pub inline fn fromBackingInt(comptime T: type, value: std.meta.Tag(T)) T {
    return @enumFromInt(value);
}
// zig fmt: on
