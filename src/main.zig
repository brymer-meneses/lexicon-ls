const std = @import("std");
const lsp = @import("lsp.zig");

pub const std_options = .{
    .logFn = @import("log.zig").log,
};

pub fn main() anyerror!void {
    const stdin = std.io.getStdIn();
    // const stdout = std.io.getStdIn();
    var buf = std.io.bufferedReader(stdin.reader());

    const reader = buf.reader();
    // const writer = stdout.writer();

    var headerBuffer: [36]u8 = undefined;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const parseOptions = .{
        .ignore_unknown_fields = true,
        .allocate = .alloc_always,
    };

    while (true) {
        const header = try reader.readUntilDelimiterOrEof(&headerBuffer, '\r');

        if (header) |h| {
            const contentLengthString = headerBuffer[("Content-Length: ".len)..h.len];
            const contentLength = try std.fmt.parseInt(u64, contentLengthString, 10);

            // skip \n\r\n
            try reader.skipBytes(3, .{});

            const content = try allocator.alloc(u8, contentLength);
            defer allocator.free(content);

            _ = try reader.readAtLeast(content, contentLength);

            const parsed = try std.json.parseFromSlice(
                struct { method: []const u8 },
                allocator,
                content,
                parseOptions,
            );
            defer parsed.deinit();

            const method = parsed.value.method;

            if (std.mem.eql(u8, method, "initialize")) {
                const initializeRequest = try std.json.parseFromSlice(
                    struct { params: lsp.InitializeRequestParams },
                    allocator,
                    content,
                    parseOptions,
                );

                lsp.handleInitializeRequest(initializeRequest.value.params);
                defer initializeRequest.deinit();
            } else {
                std.log.debug("unsupported method: {s}", .{parsed.value.method});
            }
        } else {
            std.debug.panic("Empty", .{});
            break;
        }
    }
}
