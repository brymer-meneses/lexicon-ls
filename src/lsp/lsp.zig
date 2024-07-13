const std = @import("std");
const rpc = @import("../rpc.zig");
const parser = @import("../parser.zig");

const TextDocument = @import("../text_document.zig").TextDocument;
const Language = @import("../text_document.zig").Language;
const LanguageTool = @import("../language_tool.zig").LanguageTool;

pub const types = @import("types.zig");

const extensionToLanguage = std.StaticStringMap(Language).initComptime(
    &.{
        .{ ".cpp", Language.@"C++" },
        .{ ".c", Language.C },
        .{ ".zig", Language.Zig },
        .{ ".rs", Language.Rust },
        .{ ".py", Language.Python },
    },
);

fn Server(Writer: type, Reader: type) type {
    return struct {
        const Self = @This();

        reader: Reader,
        writer: Writer,
        allocator: std.mem.Allocator,
        documents: std.ArrayList(TextDocument),

        language_tool: LanguageTool,

        pub fn initialize(self: *Self, header: types.RequestHeader, params: types.InitializeRequestParams) anyerror!void {
            try self.language_tool.start(
                params.initializationOptions.java_path,
                params.initializationOptions.language_tool_path,
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
            for (self.documents.items) |*document| {
                document.deinit();
            }
            self.documents.deinit();

            try self.language_tool.deinit();
        }

        pub fn textDocumentDidOpen(self: *Self, params: types.DidOpenTextDocumentParams) anyerror!void {
            const extension = std.fs.path.extension(params.textDocument.uri);
            const language = extensionToLanguage.get(extension);

            if (language) |lang| {
                var document = TextDocument.init(self.allocator, lang);

                try parser.parse(&document, params.textDocument.text);
                try self.documents.append(document);

                const diagnostics = try self.language_tool.getDiagnostics(&document);
                defer self.language_tool.allocator.free(diagnostics);

                std.log.warn("got {d} diagnostics", .{diagnostics.len});

                for (diagnostics) |diagnostic| {
                    std.log.warn("range {any}", .{diagnostic.range});
                }

                try rpc.send(
                    self.allocator,
                    self.writer,
                    .{
                        .jsonrpc = "2.0",
                        .method = "textDocument/publishDiagnostics",
                        .params = types.PublishDiagnosticParams{
                            .uri = params.textDocument.uri,
                            .diagnostics = diagnostics,
                        },
                    },
                );
            } else {
                std.log.info("Unsupported file extension: `{s}`.", .{extension});
            }
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
        .documents = std.ArrayList(TextDocument).init(allocator),
        .allocator = allocator,
        .reader = reader,
        .writer = writer,
        .language_tool = LanguageTool.init(allocator),
    };
}
