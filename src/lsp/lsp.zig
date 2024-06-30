const std = @import("std");
const rpc = @import("../rpc.zig");
pub const types = @import("types.zig");
pub const languagetool = @import("../backend/languagetool.zig");

fn GenericServer(Writer: type, Reader: type) type {
    return struct {
        reader: Reader,
        writer: Writer,
        allocator: std.mem.Allocator,

        java_path: ?[]const u8 = null,

        languagetool_path: ?[]const u8 = null,
        languagetool_server_thread: ?std.Thread = null,

        const Self = @This();

        pub fn textDocumentDidOpen(_: *Self, params: types.DidOpenTextDocumentParams) anyerror!void {
            std.log.debug("URI: {s}\n{s}", .{ params.textDocument.uri, params.textDocument.text });
        }

        pub fn textDocumentDidChange(_: *Self, params: types.DidChangeTextDocumentParams) anyerror!void {
            for (params.contentChanges) |change| {
                std.log.debug("Change {s}", .{change.text});
            }
        }

        pub fn initialize(self: *Self, header: types.RequestHeader, params: types.InitializeRequestParams) anyerror!void {
            self.java_path = params.initializationOptions.java_path;
            self.languagetool_path = params.initializationOptions.languagetool_path;

            self.languagetool_server_thread = try std.Thread.spawn(
                .{ .allocator = self.allocator },
                languagetool.spawnServer,
                .{
                    self.allocator,
                    params.initializationOptions.java_path,
                    params.initializationOptions.languagetool_path,
                },
            );

            try rpc.send(
                self.allocator,
                self.writer,
                .{
                    .id = header.id,
                    .jsonrpc = "2.0",

                    .result = types.InitializedResponse{
                        .capabilities = .{
                            .positionEncoding = "utf-8",
                            .textDocumentSync = .{
                                .change = .Full,
                                .openClose = true,
                            },
                        },
                        .serverInfo = .{
                            .name = "lexicon-ls",
                            .version = "0.0.1",
                        },
                    },
                },
            );
        }
    };
}

pub fn server(allocator: std.mem.Allocator, writer: anytype, reader: anytype) GenericServer(@TypeOf(writer), @TypeOf(reader)) {
    return .{
        .allocator = allocator,
        .reader = reader,
        .writer = writer,
    };
}
