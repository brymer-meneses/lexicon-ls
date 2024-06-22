const std = @import("std");

pub const DecodeResult = struct {};
pub const DecodeError = std.fmt.ParseIntError;

pub const Server = struct {
    const Self = @This();

    reader: *std.io.AnyReader,
    writer: *std.io.AnyWriter,

    pub fn init() Self {
        const stdin = std.io.getStdIn();
        const stdout = std.io.getStdIn();
        var buf = std.io.bufferedReader(stdin.reader());

        const reader = buf.reader();
        const writer = stdout.writer();

        return .{
            .reader = @as(*std.io.AnyReader, @as(*anyopaque, &reader)),
            .writer = @as(*std.io.AnyWriter, @as(*anyopaque, &writer)),
        };
    }

    pub fn start(self: *Server) void {
        var msgbuf: [4096]u8 = undefined;
        const msg = try self.reader.readUntilDelimiterOrEof(&msgbuf, '\r');

        while (true) {
            const header = self.decode(msg);
            _ = header;
        }
    }

    fn decode(_: *Server, header: []const u8) DecodeError!DecodeResult {
        const contentLength = "Content-Length: ";
        if (!std.mem.startsWith(u8, header, contentLength)) {
            std.debug.panic("Failed to get header, got {s}", .{header[0..contentLength.len]});
        }

        const lengthString = header[contentLength.len..header.len];
        const length = try std.fmt.parseInt(u64, lengthString, 10);

        std.log.debug("log: {d}", .{length});

        return .{};
    }

    fn encode(_: *Server, _: anytype) void {}
};
