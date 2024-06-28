const std = @import("std");
const rpc = @import("rpc.zig");

pub const RequestHeader = struct {
    method: []const u8,
    id: ?u64 = null,
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
    },

    serverInfo: struct {
        name: []const u8,
        version: []const u8,
    },
};

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
                },
                .serverInfo = .{
                    .name = "lexicon-ls",
                    .version = "0.0.1",
                },
            },
        },
    );
}
