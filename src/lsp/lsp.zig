const std = @import("std");
const rpc = @import("../rpc.zig");

pub const types = @import("types.zig");

fn Server(Writer: type, Reader: type) type {
    return struct {
        reader: Reader,
        writer: Writer,
        allocator: std.mem.Allocator,

        languagetool_server_process: ?std.process.Child = null,

        const Self = @This();

        pub fn textDocumentDidOpen(_: *Self, params: types.DidOpenTextDocumentParams) anyerror!void {
            std.log.debug("URI: {s}\n{s}", .{ params.textDocument.uri, params.textDocument.text });
        }

        pub fn textDocumentDidChange(_: *Self, params: types.DidChangeTextDocumentParams) anyerror!void {
            for (params.contentChanges) |change| {
                std.log.debug("Change {s}", .{change.text});
            }
        }

        pub fn shutdown(self: *Self) void {
            if (self.languagetool_server_process) |process| {
                process.kill();
            }
        }

        pub fn initialize(self: *Self, header: types.RequestHeader, params: types.InitializeRequestParams) anyerror!void {
            var process = std.process.Child.init(
                &[_][]const u8{
                    params.initializationOptions.java_path,
                    "-cp",
                    "languagetool-server.jar",
                    "org.languagetool.server.HTTPServer",
                    "--config",
                    "server.properties",
                    "--port",
                    "8081",
                    "--allow-origin",
                },
                self.allocator,
            );
            process.cwd = params.initializationOptions.languagetool_path;

            self.languagetool_server_process = process;

            try process.spawn();

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

pub fn server(allocator: std.mem.Allocator, writer: anytype, reader: anytype) Server(@TypeOf(writer), @TypeOf(reader)) {
    return .{
        .allocator = allocator,
        .reader = reader,
        .writer = writer,
    };
}
