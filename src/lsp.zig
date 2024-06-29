const std = @import("std");
const rpc = @import("rpc.zig");

pub fn handleInitializeRequest(
    allocator: std.mem.Allocator,
    writer: anytype,
    header: RequestHeader,
    _: InitializeRequestParams,
) anyerror!void {
    try rpc.encode(
        allocator,
        writer,
        .{
            .id = header.id,
            .jsonrpc = "2.0",

            .result = InitializedResponse{
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

pub fn handleTextDocumentDidOpen(
    _: std.mem.Allocator,
    _: anytype,
    _: RequestHeader,
    params: DidOpenTextDocumentParams,
) anyerror!void {
    std.log.debug("URI: {s}\n{s}", .{ params.textDocument.uri, params.textDocument.text });
}

pub fn handleTextDocumentDidChange(
    _: std.mem.Allocator,
    _: anytype,
    _: RequestHeader,
    params: DidChangeTextDocumentParams,
) anyerror!void {
    for (params.contentChanges) |change| {
        std.log.debug("Change {s}", .{change.text});
    }
}

pub const RequestHeader = struct {
    method: []const u8,
    id: ?i64 = null,
};

pub const InitializeRequestParams = struct {
    processId: ?i64 = null,
    clientInfo: struct {
        name: []const u8,
        version: ?[]const u8 = null,
    },
    locale: ?[]const u8 = null,
    rootPath: ?[]const u8 = null,
};

pub const InitializedResponse = struct {
    capabilities: struct {
        positionEncoding: []const u8,

        textDocumentSync: struct {
            openClose: bool,
            change: Kind,

            const Kind = enum(u8) {
                None = 0,
                Full = 1,
                Incremental = 2,
            };
        },
    },

    serverInfo: struct {
        name: []const u8,
        version: []const u8,
    },
};

pub const TextDocumentItem = struct {
    uri: []const u8,
    languageId: []const u8,
    version: i64,
    text: []const u8,
};

pub const DidOpenTextDocumentParams = struct {
    textDocument: TextDocumentItem,
};

pub const DidChangeTextDocumentParams = struct {
    textDocument: struct {
        uri: []const u8,
        version: i64,
    },
    contentChanges: []TextDocumentContentChangeEvent,

    pub const TextDocumentContentChangeEvent = struct {
        range: ?Range = null,
        text: []const u8,
    };

    pub const Range = struct {
        start: Position,
        end: Position,

        pub const Position = struct {
            line: u64,
            character: u64,
        };
    };
};
