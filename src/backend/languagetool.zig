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
            "8081",
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
    const url = try std.fmt.allocPrint(self.allocator, "http://localhost:{s}/check/v2", .{self.port});
    var response_storage = std.ArrayList(u8).init(self.allocator);

    while (paragraph_iterator.next()) |*paragraph| {
        _ = try paragraph.intoText(self.allocator);

        _ = try self.client.fetch(.{
            .method = .POST,
            .headers = .{
                .content_type = .{
                    .override = "application/x-www-form-urlencoded",
                },
            },
            .extra_headers = &.{
                .{ .name = "Accept", .value = "*/*" },
            },
            .server_header_buffer = null,
            .payload = "text=hi%20there&language=en-US",
            .location = .{ .url = url },
            .response_storage = .{
                .dynamic = &response_storage,
            },
        });

        std.log.debug("comments: {s}", .{response_storage.items});
    }

    return &.{};
}
