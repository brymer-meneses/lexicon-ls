const std = @import("std");

pub const DecodeResult = struct {};
pub const DecodeError = std.fmt.ParseIntError;

fn GenericServer(comptime Reader: type, comptime Writer: type) type {
    return struct {
        const Self = @This();

        reader: Reader,
        writer: Writer,

        pub fn start(self: *Self) anyerror!void {
            var msgbuf: [4096]u8 = undefined;
            const msg = try self.reader.readUntilDelimiterOrEof(&msgbuf, '\r');

            while (true) {
                if (msg) |m| {
                    const header = self.decode(m) catch unreachable;
                    _ = header;
                }
            }
        }

        fn decode(_: *Self, header: []const u8) DecodeError!DecodeResult {
            const contentLength = "Content-Length: ";
            if (!std.mem.startsWith(u8, header, contentLength)) {
                std.debug.panic("Failed to get header, got {s}", .{header[0..contentLength.len]});
            }

            const lengthString = header[contentLength.len..header.len];

            const length = try std.fmt.parseInt(u64, lengthString, 10);

            std.log.debug("log: {d}", .{length});

            return .{};
        }

        fn encode(_: *Self, _: anytype) void {}
    };
}

pub fn Server(reader: anytype, writer: anytype) GenericServer(@TypeOf(reader), @TypeOf(writer)) {
    return .{
        .reader = reader,
        .writer = writer,
    };
}
