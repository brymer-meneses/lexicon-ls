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
        languagetool_path: []const u8,
    },
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
