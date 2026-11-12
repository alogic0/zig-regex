const std = @import("std");
const version = @import("root.zig");

pub fn main(init: std.process.Init) void {
    const status = run(init) catch |err| {
        var buffer: [1024]u8 = undefined;
        var output = std.Io.File.stderr().writer(init.io, &buffer);
        output.interface.print("package-version: {s}\n", .{@errorName(err)}) catch {};
        output.interface.flush() catch {};
        std.process.exit(1);
    };
    if (status != 0) std.process.exit(status);
}

fn run(init: std.process.Init) !u8 {
    const a = init.arena.allocator();
    const args = try init.minimal.args.toSlice(a);
    var commands = args[1..];
    if (commands.len == 1 and std.mem.eql(u8, commands[0], "--help")) return usage(init, true);
    var config_path: []const u8 = "versions.zon";
    if (commands.len != 0 and std.mem.eql(u8, commands[0], "--config")) {
        if (commands.len < 2) return usage(init, false);
        config_path = commands[1];
        commands = commands[2..];
    }
    const bytes = try std.Io.Dir.cwd().readFileAllocOptions(init.io, config_path, a, .limited(1024 * 1024), .of(u8), 0);
    var diagnostics: std.zon.parse.Diagnostics = undefined;
    const files = std.zon.parse.fromSlice([]const version.FileSpec, .{
        .gpa = init.gpa,
        .arena = a,
        .source = bytes,
        .diagnostics = &diagnostics,
    }) catch |err| switch (err) {
        error.OutOfMemory => return err,
        error.ParseZon => {
            var buffer: [1024]u8 = undefined;
            var output = std.Io.File.stderr().writer(init.io, &buffer);
            try output.interface.print("package-version: {f}", .{diagnostics.fmt(config_path)});
            try output.interface.flush();
            return 1;
        },
    };
    return version.run(init, .{ .files = files, .args = commands });
}

fn usage(init: std.process.Init, help: bool) !u8 {
    var buffer: [1024]u8 = undefined;
    var output = (if (help) std.Io.File.stdout() else std.Io.File.stderr()).writer(init.io, &buffer);
    try output.interface.writeAll("Usage: zig-package-version [--config FILE.zon] [get | set MAJOR.MINOR.PATCH]\nDefaults to versions.zon. The first configured file is authoritative.\nPaths are relative to the current directory.\n");
    try output.interface.flush();
    return if (help) 0 else 1;
}
