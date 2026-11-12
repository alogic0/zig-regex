// MIT License
//
// Copyright (c) 2026 Zig Mermaid Viewer contributors
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

//! Canonical release-version synchronization; callers select files and bump policy.
const std = @import("std");

const max_file_size = 1024 * 1024;
/// Inclusive upper bound for each canonical MAJOR.MINOR.PATCH component.
pub const max_component = 65535;

/// Exact nonempty delimiters. The prefix must occur once in the source; the
/// first suffix after it ends the value. Matching is byte-based, not syntax-aware.
pub const Pattern = struct {
    prefix: []const u8,
    suffix: []const u8,
};

/// A canonical relative path and its markers, borrowed for the duration of run.
/// The first FileSpec is authoritative and must have exactly one marker.
pub const FileSpec = struct {
    path: []const u8,
    patterns: []const Pattern,
};

pub const Options = struct {
    /// Consumer-owned configuration; paths resolve from the working directory.
    files: []const FileSpec,
    /// Omit to use process arguments after argv[0].
    args: ?[]const []const u8 = null,
};

const LoadedFile = struct {
    spec: *const FileSpec,
    contents: []u8,
};

/// Check (no args or "get") or set ("set", version) the configured files.
/// Returns 0 on success or 1 after an ordinary usage/configuration/file diagnostic;
/// unexpected allocation or output errors propagate. Does not exit the process.
/// Loaded and prepared buffers are freed before returning. Set preflights all
/// replacements, then writes atomically per file with reverse rollback on failure.
/// This is not a crash-safe multi-file transaction; use a stable, trusted tree.
pub fn run(init: std.process.Init, options: Options) !u8 {
    const args = options.args orelse blk: {
        const argv = try init.minimal.args.toSlice(init.arena.allocator());
        break :blk argv[1..];
    };
    const is_get = args.len == 0 or (args.len == 1 and std.mem.eql(u8, args[0], "get"));
    const is_set = args.len == 2 and std.mem.eql(u8, args[0], "set");
    if (!is_get and !is_set) return usage(init);
    validateFiles(options.files) catch |err| return fatal(init, "invalid file configuration: {s}", .{@errorName(err)});

    const loaded = try init.gpa.alloc(LoadedFile, options.files.len);
    defer init.gpa.free(loaded);
    var loaded_count: usize = 0;
    defer for (loaded[0..loaded_count]) |file| init.gpa.free(file.contents);

    for (options.files, 0..) |*spec, index| {
        const contents = std.Io.Dir.cwd().readFileAlloc(
            init.io,
            spec.path,
            init.gpa,
            .limited(max_file_size),
        ) catch |err| return fatal(
            init,
            "cannot read '{s}': {s}",
            .{ spec.path, @errorName(err) },
        );
        loaded[index] = .{ .spec = spec, .contents = contents };
        loaded_count += 1;
    }

    const current = fileVersion(loaded[0]) catch |err| return fatal(
        init,
        "cannot read {s} version: {s}",
        .{ options.files[0].path, @errorName(err) },
    );
    if (is_get) {
        const mismatch_count = reportMismatches(init, loaded, current) catch |err| return fatal(
            init,
            "cannot compare version locations: {s}",
            .{@errorName(err)},
        );
        if (mismatch_count != 0) return 1;
        return printVersion(init, "{s}\n", .{current});
    }

    const next = args[1];
    validateVersion(next) catch return fatal(
        init,
        "invalid version '{s}': expected canonical MAJOR.MINOR.PATCH with components from 0 to {d}",
        .{ next, max_component },
    );
    const replacements = try init.gpa.alloc([]u8, options.files.len);
    defer init.gpa.free(replacements);
    var replacement_count: usize = 0;
    defer for (replacements[0..replacement_count]) |contents| init.gpa.free(contents);

    for (loaded[0..loaded_count], 0..) |file, index| {
        var updated = try init.gpa.dupe(u8, file.contents);
        errdefer init.gpa.free(updated);
        for (file.spec.patterns) |pattern| {
            const existing = extractVersion(updated, pattern) catch |err| {
                init.gpa.free(updated);
                return fatal(
                    init,
                    "cannot update '{s}': {s}",
                    .{ file.spec.path, @errorName(err) },
                );
            };
            validateVersion(existing) catch {
                init.gpa.free(updated);
                return fatal(init, "cannot update '{s}': invalid existing version", .{file.spec.path});
            };
            const replacement = replaceVersion(init.gpa, .{ .contents = updated, .pattern = pattern, .expected = existing, .replacement = next }) catch |err| {
                init.gpa.free(updated);
                return fatal(
                    init,
                    "cannot update '{s}': {s}",
                    .{ file.spec.path, @errorName(err) },
                );
            };
            init.gpa.free(updated);
            updated = replacement;
        }
        replacements[index] = updated;
        replacement_count += 1;
    }

    var written: usize = 0;
    while (written < loaded_count) : (written += 1) {
        writeAtomic(init, loaded[written].spec.path, replacements[written]) catch |err| {
            rollback(init, loaded[0..written]) catch |rollback_err| return fatal(
                init,
                "cannot update '{s}': {s}; rollback also failed: {s}",
                .{ loaded[written].spec.path, @errorName(err), @errorName(rollback_err) },
            );
            return fatal(
                init,
                "cannot update '{s}': {s}; earlier writes were rolled back",
                .{ loaded[written].spec.path, @errorName(err) },
            );
        };
    }

    if (std.mem.eql(u8, current, next)) {
        return printVersion(init, "package version synchronized at {s}\n", .{current});
    }
    return printVersion(init, "package version: {s} -> {s}\n", .{ current, next });
}

fn fileVersion(file: LoadedFile) ![]const u8 {
    if (file.spec.patterns.len != 1) return error.AmbiguousVersionFile;
    const version = try extractVersion(file.contents, file.spec.patterns[0]);
    try validateVersion(version);
    return version;
}

fn reportMismatches(
    init: std.process.Init,
    loaded: []const LoadedFile,
    expected: []const u8,
) !usize {
    var stderr_buffer: [1024]u8 = undefined;
    var stderr_writer = std.Io.File.stderr().writer(init.io, &stderr_buffer);
    var mismatch_count: usize = 0;
    for (loaded[1..]) |file| {
        const actual = try firstMismatch(file.contents, file.spec.patterns, expected) orelse continue;
        try stderr_writer.interface.print(
            "version: {s} ({s}) != {s} ({s})\n",
            .{ file.spec.path, actual, loaded[0].spec.path, expected },
        );
        mismatch_count += 1;
    }
    try stderr_writer.interface.flush();
    return mismatch_count;
}

fn firstMismatch(
    contents: []const u8,
    patterns: []const Pattern,
    expected: []const u8,
) !?[]const u8 {
    for (patterns) |pattern| {
        const actual = try extractVersion(contents, pattern);
        if (!std.mem.eql(u8, actual, expected)) return actual;
    }
    return null;
}

/// Borrow the nonempty text between unique-prefix markers from contents.
/// The returned slice shares contents' lifetime. Version syntax is not checked;
/// call validateVersion separately when using extraction on its own.
pub fn extractVersion(contents: []const u8, pattern: Pattern) ![]const u8 {
    if (pattern.prefix.len == 0 or pattern.suffix.len == 0) return error.InvalidVersionMarker;
    const prefix_index = std.mem.indexOf(u8, contents, pattern.prefix) orelse
        return error.MissingVersion;
    const value_start = prefix_index + pattern.prefix.len;
    const suffix_offset = std.mem.indexOf(u8, contents[value_start..], pattern.suffix) orelse
        return error.MissingVersion;
    if (std.mem.indexOf(u8, contents[value_start..], pattern.prefix) != null)
        return error.DuplicateVersionMarker;
    const value = contents[value_start .. value_start + suffix_offset];
    if (value.len == 0) return error.InvalidVersion;
    return value;
}

/// Accept canonical numeric MAJOR.MINOR.PATCH with each part <= max_component.
/// Leading zeros, prerelease/build metadata and all other forms are rejected.
pub fn validateVersion(text: []const u8) !void {
    const parsed = std.SemanticVersion.parse(text) catch return error.InvalidVersion;
    if (parsed.pre != null or parsed.build != null or
        parsed.major > max_component or parsed.minor > max_component or parsed.patch > max_component)
        return error.InvalidVersion;

    var canonical_buffer: [32]u8 = undefined;
    const canonical = std.fmt.bufPrint(
        &canonical_buffer,
        "{d}.{d}.{d}",
        .{ parsed.major, parsed.minor, parsed.patch },
    ) catch return error.InvalidVersion;
    if (!std.mem.eql(u8, canonical, text)) return error.InvalidVersion;
}

/// Borrowed inputs used only for the duration of replaceVersion.
pub const Replacement = struct {
    contents: []const u8,
    pattern: Pattern,
    expected: []const u8,
    replacement: []const u8,
};

/// Validate expected/replacement versions, require the marked value to match
/// expected, and return an independent allocator-owned buffer. The caller must
/// free the result with allocator. The source buffer is never modified.
pub fn replaceVersion(allocator: std.mem.Allocator, request: Replacement) ![]u8 {
    const contents = request.contents;
    const pattern = request.pattern;
    const expected = request.expected;
    const replacement = request.replacement;
    try validateVersion(expected);
    try validateVersion(replacement);
    const found = try extractVersion(contents, pattern);
    if (!std.mem.eql(u8, found, expected)) return error.InconsistentVersion;
    const value_start = @intFromPtr(found.ptr) - @intFromPtr(contents.ptr);
    const new_len = std.math.sub(usize, contents.len, found.len) catch return error.FileTooLarge;
    const final_len = std.math.add(usize, new_len, replacement.len) catch return error.FileTooLarge;
    const updated = try allocator.alloc(u8, final_len);
    @memcpy(updated[0..value_start], contents[0..value_start]);
    @memcpy(updated[value_start .. value_start + replacement.len], replacement);
    @memcpy(
        updated[value_start + replacement.len ..],
        contents[value_start + found.len ..],
    );
    return updated;
}

fn writeAtomic(init: std.process.Init, path: []const u8, contents: []const u8) !void {
    const cwd = std.Io.Dir.cwd();
    const permissions = permissions: {
        const original = try cwd.openFile(init.io, path, .{});
        defer original.close(init.io);
        break :permissions (try original.stat(init.io)).permissions;
    };

    var atomic = try cwd.createFileAtomic(init.io, path, .{
        .permissions = permissions,
        .replace = true,
    });
    defer atomic.deinit(init.io);
    try atomic.file.writeStreamingAll(init.io, contents);
    // File creation applies umask; restore the original bits before publication.
    try atomic.file.setPermissions(init.io, permissions);
    try atomic.replace(init.io);
}

fn rollback(init: std.process.Init, written: []const LoadedFile) !void {
    var index = written.len;
    while (index > 0) {
        index -= 1;
        try writeAtomic(init, written[index].spec.path, written[index].contents);
    }
}

/// Check configuration shape without IO: 1..256 unique canonical relative paths,
/// one primary marker, and 1..256 nonempty marker pairs per file. This does not
/// resolve symlinks, inspect files or establish a filesystem security boundary.
pub fn validateFiles(files: []const FileSpec) !void {
    if (files.len == 0 or files.len > 256) return error.InvalidFileCount;
    if (files[0].patterns.len != 1) return error.AmbiguousVersionFile;
    for (files, 0..) |file, index| {
        if (file.path.len == 0 or std.fs.path.isAbsolute(file.path) or
            std.mem.indexOfAny(u8, file.path, "\\\x00") != null) return error.InvalidFilePath;
        var parts = std.mem.splitScalar(u8, file.path, '/');
        while (parts.next()) |part| {
            if (part.len == 0 or std.mem.eql(u8, part, ".") or std.mem.eql(u8, part, "..")) return error.InvalidFilePath;
        }
        for (files[0..index]) |previous| {
            if (std.mem.eql(u8, file.path, previous.path)) return error.DuplicateFilePath;
        }
        if (file.patterns.len == 0 or file.patterns.len > 256) return error.InvalidMarkerCount;
        for (file.patterns) |pattern| {
            if (pattern.prefix.len == 0 or pattern.suffix.len == 0) return error.InvalidVersionMarker;
        }
    }
}

fn printVersion(init: std.process.Init, comptime format: []const u8, args: anytype) !u8 {
    var stdout_buffer: [256]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(init.io, &stdout_buffer);
    try stdout_writer.interface.print(format, args);
    try stdout_writer.interface.flush();
    return 0;
}

fn usage(init: std.process.Init) u8 {
    return fatal(
        init,
        "usage: version [get]\n       version set MAJOR.MINOR.PATCH",
        .{},
    );
}

fn fatal(init: std.process.Init, comptime format: []const u8, args: anytype) u8 {
    var stderr_buffer: [1024]u8 = undefined;
    var stderr_writer = std.Io.File.stderr().writer(init.io, &stderr_buffer);
    stderr_writer.interface.print("version: " ++ format ++ "\n", args) catch {};
    stderr_writer.interface.flush() catch {};
    return 1;
}

test "accepts only canonical release versions" {
    try validateVersion("0.1.0");
    try validateVersion("65535.0.42");
    try std.testing.expectError(error.InvalidVersion, validateVersion("1.2"));
    try std.testing.expectError(error.InvalidVersion, validateVersion("01.2.3"));
    try std.testing.expectError(error.InvalidVersion, validateVersion("1.2.3-beta.1"));
    try std.testing.expectError(error.InvalidVersion, validateVersion("1.2.65536"));
}

test "extracts and replaces one marked version" {
    const pattern: Pattern = .{ .prefix = "version = \"", .suffix = "\";" };
    const source = "const version = \"0.1.0\";\n";
    try std.testing.expectEqualStrings("0.1.0", try extractVersion(source, pattern));

    const updated = try replaceVersion(std.testing.allocator, .{ .contents = source, .pattern = pattern, .expected = "0.1.0", .replacement = "0.2.0" });
    defer std.testing.allocator.free(updated);
    try std.testing.expectEqualStrings("const version = \"0.2.0\";\n", updated);
}

test "rejects missing duplicate and inconsistent markers before allocation" {
    const pattern: Pattern = .{ .prefix = "version = \"", .suffix = "\";" };
    try std.testing.expectError(error.MissingVersion, extractVersion("name = \"example\";", pattern));
    try std.testing.expectError(error.DuplicateVersionMarker, extractVersion("version = \"1.0.0\"; version = \"1.0.0\";", pattern));
    try std.testing.expectError(error.InvalidVersionMarker, extractVersion("1.0.0", .{ .prefix = "", .suffix = ";" }));
    try std.testing.expectError(error.InconsistentVersion, replaceVersion(std.testing.allocator, .{
        .contents = "version = \"1.0.0\";",
        .pattern = pattern,
        .expected = "1.0.1",
        .replacement = "1.0.2",
    }));
    try std.testing.expectError(error.InvalidVersion, replaceVersion(std.testing.allocator, .{
        .contents = "version = \"1.0.0\";",
        .pattern = pattern,
        .expected = "1.0.0",
        .replacement = "invalid",
    }));
}

test "checks each marker and reports the first mismatch per file" {
    const patterns = &[_]Pattern{
        .{ .prefix = "version = \"", .suffix = "\";" },
        .{ .prefix = "archive = \"", .suffix = "\";" },
    };
    try std.testing.expectEqual(@as(?[]const u8, null), try firstMismatch("version = \"0.3.1\"; archive = \"0.3.1\";", patterns, "0.3.1"));
    try std.testing.expectEqualStrings("0.3.0", (try firstMismatch("version = \"0.3.1\"; archive = \"0.3.0\";", patterns, "0.3.1")).?);
}

test "validates the complete file configuration" {
    const patterns = &[_]Pattern{.{ .prefix = "version=", .suffix = ";" }};
    try validateFiles(&.{.{ .path = "src/version.zig", .patterns = patterns }});
    try std.testing.expectError(error.InvalidFileCount, validateFiles(&.{}));
    try std.testing.expectError(error.AmbiguousVersionFile, validateFiles(&.{.{ .path = "version", .patterns = &.{} }}));
    for ([_][]const u8{ "", "../version", "/tmp/version", "a//version", "./version", "a/../version", "a\\version", "ver\x00sion" }) |path| {
        try std.testing.expectError(error.InvalidFilePath, validateFiles(&.{.{ .path = path, .patterns = patterns }}));
    }
    try std.testing.expectError(error.DuplicateFilePath, validateFiles(&.{
        .{ .path = "version", .patterns = patterns },
        .{ .path = "version", .patterns = patterns },
    }));
    try std.testing.expectError(error.InvalidMarkerCount, validateFiles(&.{
        .{ .path = "version", .patterns = patterns },
        .{ .path = "other", .patterns = &.{} },
    }));
}

fn replacementAllocation(allocator: std.mem.Allocator) !void {
    const source = "before\nversion=1.2.3;\nafter\n";
    const updated = try replaceVersion(allocator, .{
        .contents = source,
        .pattern = .{ .prefix = "version=", .suffix = ";" },
        .expected = "1.2.3",
        .replacement = "65535.42.0",
    });
    defer allocator.free(updated);
    try std.testing.expectEqualStrings("before\nversion=65535.42.0;\nafter\n", updated);
    try std.testing.expectEqualStrings("before\nversion=1.2.3;\nafter\n", source);
}

test "replacement ownership survives allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, replacementAllocation, .{});
}
