const std = @import("std");
const types = @import("../lsp/types.zig");

const TextDocument = @import("../text_document.zig").TextDocument;

const LanguageTool = @This();
const Self = @This();

port: []const u8,
process: ?std.process.Child = null,
java_path: []const u8,
languagetool_path: []const u8,
allocator: std.mem.Allocator,
client: std.http.Client,

pub fn init(allocator: std.mem.Allocator, java_path: []const u8, languagetool_path: []const u8, port: []const u8) !Self {
    return .{
        .client = std.http.Client{ .allocator = allocator },
        .allocator = allocator,
        .port = port,
        .languagetool_path = languagetool_path,
        .java_path = java_path,
    };
}

pub fn start(self: *Self) !void {
    if (self.process == null) {
        self.process = std.process.Child.init(&.{
            self.java_path,
            "-cp",
            "languagetool-server.jar",
            "org.languagetool.server.HTTPServer",
            "--config",
            "server.properties",
            "--port",
            self.port,
            "--allow-origin",
        }, self.allocator);
        self.process.?.cwd = self.languagetool_path;
        try self.process.?.spawn();
    }
}

pub fn deinit(self: *Self) !void {
    if (self.process) |*process| {
        _ = try process.kill();
    }
}

pub fn getDiagnostics(self: *Self, doc: *TextDocument) ![]const types.Diagnostic {
    var paragraph_iterator = doc.iter();
    const url = try std.fmt.allocPrint(self.allocator, "http://localhost:{s}/v2/check", .{self.port});
    defer self.allocator.free(url);

    var response_storage = std.ArrayList(u8).init(self.allocator);
    defer response_storage.deinit();

    var payload_storage = std.ArrayList(u8).init(self.allocator);
    defer response_storage.deinit();

    while (paragraph_iterator.next()) |*paragraph| {
        const text = try paragraph.intoText(self.allocator);

        try encodeParams(
            .{
                .language = "en-US",
                .text = text,
            },
            payload_storage.writer(),
        );

        const fetch_result = try self.client.fetch(.{
            .method = .POST,
            .server_header_buffer = null,
            .payload = payload_storage.items,
            .location = .{ .url = url },
            .response_storage = .{
                .dynamic = &response_storage,
            },
        });

        switch (fetch_result.status) {
            .ok => {},
            else => return error.BadRequest,
        }

        std.log.debug("response: {s}", .{response_storage.items});
    }

    return &.{};
}

pub fn encodeParams(params: anytype, writer: anytype) !void {
    var is_first = true;

    inline for (std.meta.fields(@TypeOf(params))) |field| {
        if (is_first) {
            is_first = false;
        } else {
            try writer.writeAll("&");
        }

        try writer.print("{%}={%}", .{
            std.Uri.Component{ .raw = field.name },
            std.Uri.Component{ .raw = @field(params, field.name) },
        });
    }
}
