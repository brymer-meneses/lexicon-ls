const std = @import("std");
const rpc = @import("../rpc.zig");
const parser = @import("../parsers/parser.zig");

const TextDocument = @import("../text_document.zig").TextDocument;
const LanguageTool = @import("../backend/LanguageTool.zig");

pub const types = @import("types.zig");

fn Server(Writer: type, Reader: type) type {
    return struct {
        const Self = @This();

        reader: Reader,
        writer: Writer,
        allocator: std.mem.Allocator,

        text_documents: std.ArrayList(TextDocument),

        languagetool: ?LanguageTool = null,

        pub fn initialize(self: *Self, header: types.RequestHeader, params: types.InitializeRequestParams) anyerror!void {
            self.languagetool = try LanguageTool.init(
                self.allocator,
                params.initializationOptions.java_path,
                params.initializationOptions.languagetool_path,
                "8081",
            );
            try self.languagetool.?.start();

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
                                .change = types.TextDocumentSyncKind.Incremental,
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

            self.text_documents.deinit();

            if (self.languagetool) |*languagetool| {
                try languagetool.deinit();
            }
        }

        pub fn textDocumentDidOpen(self: *Self, params: types.DidOpenTextDocumentParams) anyerror!void {
            std.log.debug("URI: {s}\n{s}", .{ params.textDocument.uri, params.textDocument.text });

            var document = try parser.parse(self.allocator, params.textDocument.text, params.textDocument.uri);
            if (document) |doc| {
                try self.text_documents.append(doc);
            }

            if (document) |*doc| {
                _ = try self.languagetool.?.getDiagnostics(doc);
            } else {
                std.log.warn("Got a null `TextDocument", .{});
            }
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
