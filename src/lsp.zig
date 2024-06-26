const std = @import("std");

pub fn Request(Params: type) type {
    return struct {
        jsonrpc: []const u8,
        id: u64,
        method: []const u8,
        params: Params,
    };
}

pub const InitializeRequestParams = struct {
    processId: ?i64 = null,
    clientInfo: struct {
        name: []const u8,
        version: ?[]const u8 = null,
    },

    locale: ?[]const u8 = null,
    rootPath: ?[]const u8 = null,
};

pub fn handleInitializeRequest(params: InitializeRequestParams) void {
    std.log.debug("{any}\n", .{params});
}
