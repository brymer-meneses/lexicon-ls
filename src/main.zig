const std = @import("std");
const Server = @import("server.zig").Server;

pub const std_options = .{
    .logFn = @import("log.zig").log,
};

pub fn main() !void {
    const stdin = std.io.getStdIn();
    const stdout = std.io.getStdIn();
    var buf = std.io.bufferedReader(stdin.reader());

    const reader = buf.reader();
    const writer = stdout.writer();
    var server = Server(reader, writer);

    server.start() catch |err| {
        std.debug.panic("{any}", .{err});
    };
}
