const std = @import("std");
const rpc = @import("../rpc.zig");

const LanguageTool = @import("../backend/LanguageTool.zig");

pub const types = @import("types.zig");

fn Server(Writer: type, Reader: type) type {
    return struct {
        const Self = @This();

        reader: Reader,
        writer: Writer,
        allocator: std.mem.Allocator,

        languagetool: LanguageTool,

        pub fn initialize(self: *Self, header: types.RequestHeader, params: types.InitializeRequestParams) anyerror!void {
            try self.languagetool.start(
                params.initializationOptions.java_path,
                params.initializationOptions.languagetool_path,
                8081,
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
                                .change = types.TextDocumentSyncKind.Full,
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
            // for (self.text_documents.items) |*document| {
            //     document.deinit();
            // }
            //
            // self.text_documents.deinit();
            try self.languagetool.deinit();
        }

        pub fn textDocumentDidOpen(_: *Self, _: types.DidOpenTextDocumentParams) anyerror!void {
            // const document = try parser.parse(self.allocator, params.textDocument.text, params.textDocument.uri);

            // _ = document;
        }

        pub fn textDocumentDidChange(_: *Self, params: types.DidChangeTextDocumentParams) anyerror!void {
            for (params.contentChanges, 0..) |change, i| {
                std.log.info("Change {d}:\n{s} {any}", .{ i, change.text, change.range.? });
            }
        }
    };
}

pub fn server(allocator: std.mem.Allocator, writer: anytype, reader: anytype) Server(@TypeOf(writer), @TypeOf(reader)) {
    return .{
        // .text_documents = std.ArrayList(TextDocument).init(allocator),
        .allocator = allocator,
        .reader = reader,
        .writer = writer,
        .languagetool = LanguageTool.init(allocator),
    };
}
