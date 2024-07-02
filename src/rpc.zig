const std = @import("std");

pub fn receive(allocator: std.mem.Allocator, reader: anytype) anyerror![]const u8 {
    var headerBuffer: [36]u8 = undefined;

    if (try reader.readUntilDelimiterOrEof(&headerBuffer, '\r')) |header| {
        const contentLengthString = headerBuffer[("Content-Length: ".len)..header.len];
        const contentLength = try std.fmt.parseInt(u64, contentLengthString, 10);
        try reader.skipBytes(3, .{}); // skip \n\r\n

        const content = try allocator.alloc(u8, contentLength);
        const parsedContentSize = try reader.readAtLeast(content, contentLength);
        std.debug.assert(parsedContentSize == contentLength);

        return content;
    } else {
        std.debug.panic("Invalid content passed\n", .{});
    }
}

pub fn send(allocator: std.mem.Allocator, writer: anytype, value: anytype) anyerror!void {
    const content = try std.json.stringifyAlloc(allocator, value, .{ .whitespace = .minified });
    defer allocator.free(content);

    try writer.print("Content-Length: {d}\r\n\r\n{s}", .{ content.len, content });
}

test send {
    const allocator = std.testing.allocator;

    const value = .{ .message = "Hi there!" };

    const buffer = try allocator.alloc(u8, 64);
    defer allocator.free(buffer);

    var stream = std.io.fixedBufferStream(buffer);
    const writer = stream.writer();

    try send(allocator, writer, value);

    try std.testing.expectStringStartsWith(buffer, "Content-Length: 23\r\n\r\n{\"message\":\"Hi there!\"}");
}

test receive {
    const allocator = std.testing.allocator;
    const value = "Content-Length: 23\r\n\r\n{\"message\":\"Hi there!\"}";

    var stream = std.io.fixedBufferStream(value);
    const reader = stream.reader();
    const content = try receive(allocator, reader);
    defer allocator.free(content);

    const received = try std.json.parseFromSlice(struct { message: []const u8 }, allocator, content, .{});
    defer received.deinit();

    try std.testing.expectEqual(23, content.len);
    try std.testing.expectEqualStrings(received.value.message, "Hi there!");
}
