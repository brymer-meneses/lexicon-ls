const std = @import("std");

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

    initializationOptions: struct {
        java_path: []const u8,
        language_tool_path: []const u8,
    },
};

pub const InitializedResponse = struct {
    capabilities: struct {
        positionEncoding: []const u8,
        textDocumentSync: struct {
            openClose: bool,
            change: TextDocumentSyncKind,
        },
    },

    serverInfo: struct {
        name: []const u8,
        version: []const u8,
    },
};

pub const TextDocumentSyncKind = enum(u2) {
    None = 0,
    Full = 1,
    Incremental = 2,

    pub fn jsonStringify(self: TextDocumentSyncKind, jw: anytype) !void {
        try jw.print("{d}", .{@intFromEnum(self)});
    }
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
};

pub const Range = struct {
    start: Position,
    end: Position,
};

pub const Position = struct {
    line: u64,
    character: u64,
};

pub const Diagnostic = struct {
    range: Range,
    message: []const u8,
    severity: Severity,
    source: []const u8,

    pub const Severity = enum(u8) {
        Error = 1,
        Warning = 2,
        Information = 3,
        Hint = 4,

        pub fn jsonStringify(self: Severity, jw: anytype) !void {
            try jw.print("{d}", .{@intFromEnum(self)});
        }
    };
};

pub const PublishDiagnosticParams = struct {
    uri: []const u8,
    diagnostics: []const Diagnostic,
};

test "proper enum encoding" {
    const allocator = std.testing.allocator;
    const string = try std.json.stringifyAlloc(
        allocator,
        .{ .severity = Diagnostic.Severity.Hint },
        .{ .whitespace = .minified },
    );
    defer allocator.free(string);
    const string1 = try std.json.stringifyAlloc(
        allocator,
        .{ .sync = TextDocumentSyncKind.Incremental },
        .{ .whitespace = .minified },
    );
    defer allocator.free(string1);

    try std.testing.expectEqualStrings("{\"severity\":4}", string);
    try std.testing.expectEqualStrings("{\"sync\":2}", string1);
}
