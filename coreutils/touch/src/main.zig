const std = @import("std");
const Io = std.Io;

// This is a new feature called "juicy main". It makes it easy to allocate cli arguments to a slice
pub fn main(init: std.process.Init) !void {
    // This io interface is how to interact with IO.
    const io = init.io;

    // This is an allocator for mapping cli arguments to a slice.
    const arena: std.mem.Allocator = init.arena.allocator();

    // Allocate the cli arguments to a slice using an area allocator.
    // An area allocator is a good fit as cli aruments are of unknown size. It's also fast.
    const args = try init.minimal.args.toSlice(arena);
    if (args.len < 2) {
        std.debug.print("Path required\n Example: touch-zig testfile.txt\n", .{});
        return error.InvalidPath;
    }
    const path = args[1];
    _ = try touchMe(std.Io.Dir.cwd(), path, io);
}

/// Touches a file at a given path. If the file doesn't exist, it will be created. If it does exist, it's timestamps will be updated to the current time.
fn touchMe(dir: std.Io.Dir, path: []const u8, io: Io) !std.Io.Dir.Stat {
    var stat = dir.statFile(io, path, .{}) catch |err| {
        switch (err) {
            error.FileNotFound => {
                const newFile = try dir.createFile(io, path, .{});
                defer newFile.close(io);
                const stat = try newFile.stat(io);
                return stat;
            },
            else => return err,
        }
    };
    if (stat.kind == .file) {
        var myFile = try dir.openFile(io, path, .{ .mode = .write_only });
        defer myFile.close(io);
        try myFile.setTimestampsNow(io);
        stat = try dir.statFile(io, path, .{});
        return stat;
    } else {
        return error.NotAFile;
    }
}

test "test create new file" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const io = std.testing.io;
    const stat = try touchMe(tmp.dir, "test.txt", io);
    try std.testing.expect(stat.size == 0);
}

test "test update existing file" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const io = std.testing.io;
    const file = try tmp.dir.createFile(io, "test.txt", .{});
    defer file.close(io);

    var buffer: [1024]u8 = undefined;
    var file_writer = file.writer(io, &buffer);

    const writer = &file_writer.interface;

    try writer.print("Hello", .{});
    try writer.flush();

    const stat = try touchMe(tmp.dir, "test.txt", io);
    try std.testing.expect(stat.size == 5);
}
