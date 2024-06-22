const std = @import("std");
const Server = @import("server.zig").Server;

pub const std_options = .{
    .logFn = @import("log.zig").log,
};

pub fn main() !void {
    var server = Server.init();
    server.start();
}
