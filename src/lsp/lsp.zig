const std = @import("std");
const rpc = @import("../rpc.zig");

const TextDocument = @import("../text_document.zig").TextDocument;

pub const types = @import("types.zig");

fn Server(Writer: type, Reader: type) type {
    return struct {
        const Self = @This();

        reader: Reader,
        writer: Writer,
        allocator: std.mem.Allocator,

        languagetool_server_process: ?std.process.Child = null,

        text_documents: std.ArrayList(TextDocument),

        pub fn initialize(self: *Self, header: types.RequestHeader, params: types.InitializeRequestParams) anyerror!void {
            var process = std.process.Child.init(
                &.{
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
                                .change = @intFromEnum(types.TextDocumentSyncKind.Incremental),
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

        pub fn shutdown(self: *Self) anyerror!void {
            for (self.text_documents.items) |*document| {
                document.deinit();
            }
            if (self.languagetool_server_process) |*process| {
                _ = try process.kill();
            }
        }

        pub fn textDocumentDidOpen(self: *Self, params: types.DidOpenTextDocumentParams) anyerror!void {
            std.log.debug("URI: {s}\n{s}", .{ params.textDocument.uri, params.textDocument.text });
            const text_document = TextDocument.init(self.allocator, params.textDocument.uri);
            try self.text_documents.append(text_document);
        }

        pub fn textDocumentDidChange(_: *Self, params: types.DidChangeTextDocumentParams) anyerror!void {
            for (params.contentChanges, 0..) |change, i| {
                std.log.debug("Change {d}:\n{s} {any}", .{ i, change.text, change.range.? });
            }
        }
    };
}

pub fn server(allocator: std.mem.Allocator, writer: anytype, reader: anytype) Server(@TypeOf(writer), @TypeOf(reader)) {
    return .{
        .text_documents = std.ArrayList(TextDocument).init(allocator),
        .allocator = allocator,
        .reader = reader,
        .writer = writer,
    };
}
