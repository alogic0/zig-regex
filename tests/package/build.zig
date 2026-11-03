const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const regex = b.dependency("regex", .{ .target = target, .optimize = optimize }).module("regex");
    const tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "regex", .module = regex }},
    }) });
    const run = b.addRunArtifact(tests);
    run.has_side_effects = true;
    b.step("test", "Verify an independent package caller").dependOn(&run.step);
}
