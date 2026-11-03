const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const filter = b.option([]const u8, "test-filter", "Run tests whose names contain this text");
    const module = b.addModule("regex", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    const tests = b.addTest(.{
        .root_module = module,
        .filters = if (filter) |value| &.{value} else &.{},
    });
    const run_tests = b.addRunArtifact(tests);
    run_tests.has_side_effects = true;
    b.step("test", "Run regex unit and public API tests").dependOn(&run_tests.step);

    const example = b.addExecutable(.{
        .name = "regex-example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/basic.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "regex", .module = module }},
        }),
    });
    b.installArtifact(example);
    const run_example = b.addRunArtifact(example);
    run_example.has_side_effects = true;
    b.step("example", "Run the capture and ownership example").dependOn(&run_example.step);

    const wasm_target = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .freestanding });
    const wasm_regex = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = wasm_target,
        .optimize = optimize,
    });
    const wasm = b.addExecutable(.{
        .name = "regex-check",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/wasm.zig"),
            .target = wasm_target,
            .optimize = optimize,
            .imports = &.{.{ .name = "regex", .module = wasm_regex }},
        }),
    });
    wasm.entry = .disabled;
    wasm.root_module.export_symbol_names = &.{"regexAcceptance"};
    const install_wasm = b.addInstallArtifact(wasm, .{});
    const check = b.step("check", "Compile the native example and freestanding Wasm caller");
    check.dependOn(&example.step);
    check.dependOn(&install_wasm.step);

    const run_wasm = b.addSystemCommand(&.{"node"});
    run_wasm.addFileArg(b.path("tests/run-wasm.mjs"));
    run_wasm.addFileArg(wasm.getEmittedBin());
    run_wasm.has_side_effects = true;
    b.step("test-wasm", "Execute the freestanding Wasm public API check in Node.js").dependOn(&run_wasm.step);
}
