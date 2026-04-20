const std = @import("std");
const print = std.debug.print;

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const path = if (args.len > 1) args[1] else ".";

    var buf: [1024]u8 = undefined;
    var w = std.fs.File.stdout().writer(&buf);
    const writer = &w.interface;

    listItems(path, writer) catch |err| {
        print("ls: {s}: {}\n", .{ path, err });
        std.process.exit(1);
    };
}

/// Lists the contents of a given path to the provided writer. The path must exist and be a directory, otherwise an error is returned.
/// Directories are printed with a trailing slash, while files are printed without. The writer is flushed at the end of the function, but it is the caller's responsibility to ensure that the buffer is large enough to hold the output, or to handle flushing as needed.
/// Returns error.FileNotFound if the path does not exist, error.FileExpected if the path exists but is not a directory, or any other error encountered while reading the directory.
fn listItems(path: []const u8, writer: anytype) !void {
    _ = try std.fs.cwd().statFile(path);
    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
    defer dir.close();

    var iter = dir.iterate();

    while (try iter.next()) |entry| {
        switch (entry.kind) {
            .file => try writer.print("{s}\n", .{entry.name}),
            .directory => try writer.print("{s}/\n", .{entry.name}),
            else => {},
        }
    }
    writer.flush() catch {};
}

test "ls cwd" {
    // This shows that the zig writer interface autoflushes. So I can deliberately undersize the buffer and it still works (but will be slower that it could be)
    var buf: [32]u8 = undefined;
    var w = std.fs.File.stderr().writer(&buf);
    const writer = &w.interface;
    print("Listing current directory:\n", .{});
    try listItems(".", writer);
}

test "ls temp directory" {
    var buf: [32]u8 = undefined;
    var w = std.fs.File.stderr().writer(&buf);
    const writer = &w.interface;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(.{ .sub_path = "file1.txt", .data = "Hello, Zig!" });
    try tmp.dir.makeDir("subdir");
    print("Listing temp directory:\n", .{});
    const path = try tmp.dir.realpathAlloc(std.testing.allocator, ".");
    defer std.testing.allocator.free(path);
    try listItems(path, writer);
}

test "ls non-existent directory" {
    var buf: [32]u8 = undefined;
    var w = std.fs.File.stderr().writer(&buf);
    const writer = &w.interface;
    print("Listing non-existent directory:\n", .{});
    try std.testing.expectError(error.FileNotFound, listItems("this_directory_does_not_exist", writer));
}
