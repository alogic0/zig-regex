const std = @import("std");
const regex = @import("regex/root.zig");

test "vendored regex matches validation patterns" {
    var compiled = try regex.compileRe(std.testing.allocator, "[A-Za-z]+\\s+needle$", .{});
    defer compiled.deinit();

    try std.testing.expect(try compiled.isMatch("local needle"));
    try std.testing.expect(!try compiled.isMatch("local needle extra"));
}

test "public API releases partial compilation and matching on allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, compileAndMatch, .{});
    for ([_]MatchCase{
        .{ .pattern = "needle", .text = "needle" },
        .{ .pattern = "(?i)(ab)+", .text = "ABAB" },
        .{ .pattern = "(?:ab){0,3}(c)?", .text = "ababc" },
        .{ .pattern = "[\\p{Greek}&&\\p{Uppercase}]+", .text = "ΣΣ" },
        .{ .pattern = "([^a]+)", .text = "\xffΣ", .raw_bytes = true },
    }) |case| {
        try std.testing.checkAllAllocationFailures(std.testing.allocator, compileMatchCase, .{case});
    }
}

fn compileAndMatch(allocator: std.mem.Allocator) !void {
    var compiled = try regex.compileRe(allocator, "(?P<word>σ+|[ab]+)-(?P<number>[0-9]+)", .{
        .case_insensitive = true,
        .max_instructions = 4096,
    });
    defer compiled.deinit();
    const found = (try compiled.firstMatch("ΣΣ-42")) orelse return error.MissingMatch;
    defer found.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 2), found.groups.len);
    try std.testing.expectEqual(regex.vm.Capture{ .start = 0, .end = 7 }, found.span);
}

const MatchCase = struct { pattern: []const u8, text: []const u8, raw_bytes: bool = false };

fn compileMatchCase(allocator: std.mem.Allocator, case: MatchCase) !void {
    var compiled = try regex.compileRe(allocator, case.pattern, .{ .max_instructions = 4096 });
    defer compiled.deinit();
    const found = (if (case.raw_bytes)
        try compiled.firstMatchBytes(case.text)
    else
        try compiled.firstMatch(case.text)) orelse return error.MissingMatch;
    defer found.deinit(allocator);
    try std.testing.expectEqual(regex.vm.Capture{ .start = 0, .end = case.text.len }, found.span);
    if (!case.raw_bytes) try std.testing.expect(try compiled.isMatch(case.text));
}

test "public API releases partial ASTs on rejected named and unnamed groups" {
    for ([_][]const u8{ "([ab]+|cd", "(?P<word>[ab]+", "(?P<one>ab)(?P<two>cd" }) |pattern| {
        try std.testing.expectError(error.UnterminatedGroup, regex.compileRe(std.testing.allocator, pattern, .{}));
    }
}

test "literal prefilters release previous copies on allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, duplicatePrefilters, .{});
}

fn duplicatePrefilters(allocator: std.mem.Allocator) !void {
    const prefilter = (try regex.Literal.duplicatePrefilter(allocator, &.{
        .{ .bytes = "first" }, .{ .bytes = "second" },
    })).?;
    defer prefilter.deinit(allocator);
    try std.testing.expect(prefilter.mayMatch("second"));
}

test "public API honors inline case folding with either global default" {
    var enabled = try regex.compileRe(std.testing.allocator, "(?i)^cat(?-i:Dog)$", .{});
    defer enabled.deinit();
    try std.testing.expect(try enabled.isMatch("CATDog"));
    try std.testing.expect(!try enabled.isMatch("CATDOG"));

    var disabled = try regex.compileRe(std.testing.allocator, "(?-i)^cat$", .{ .case_insensitive = true });
    defer disabled.deinit();
    try std.testing.expect(try disabled.isMatch("cat"));
    try std.testing.expect(!try disabled.isMatch("CAT"));
}
