const std = @import("std");
const lsp = @import("lsp/lsp.zig");
const rpc = @import("rpc.zig");

pub const std_options = .{
    .logFn = @import("log.zig").log,
};

test {
    std.testing.refAllDecls(rpc);
}

pub fn main() anyerror!void {
    const stdin = std.io.getStdIn();
    const stdout = std.io.getStdOut();
    var buf = std.io.bufferedReader(stdin.reader());

    const reader = buf.reader();
    const writer = stdout.writer();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    const jsonOptions = .{
        .ignore_unknown_fields = true,
        .allocate = .alloc_always,
    };

    var server = lsp.server(allocator, writer, reader);

    while (true) {
        const content = try rpc.decode(allocator, reader);
        defer allocator.free(content);

        const requestHeader = try std.json.parseFromSlice(
            lsp.types.RequestHeader,
            allocator,
            content,
            jsonOptions,
        );
        defer requestHeader.deinit();

        if (std.mem.eql(u8, requestHeader.value.method, "initialize")) {
            const request = try std.json.parseFromSlice(
                struct { params: lsp.types.InitializeRequestParams },
                allocator,
                content,
                jsonOptions,
            );
            defer request.deinit();

            try server.initialize(requestHeader.value, request.value.params);
        } else if (std.mem.eql(u8, requestHeader.value.method, "textDocument/didOpen")) {
            const request = try std.json.parseFromSlice(
                struct { params: lsp.types.DidOpenTextDocumentParams },
                allocator,
                content,
                jsonOptions,
            );
            defer request.deinit();

            try server.textDocumentDidOpen(request.value.params);
        } else if (std.mem.eql(u8, requestHeader.value.method, "textDocument/didChange")) {
            const request = try std.json.parseFromSlice(
                struct { params: lsp.types.DidChangeTextDocumentParams },
                allocator,
                content,
                jsonOptions,
            );
            defer request.deinit();

            try server.textDocumentDidChange(request.value.params);
        } else if (std.mem.eql(u8, requestHeader.value.method, "initialized")) {
            std.log.debug("Successfully initialized with client!", .{});
        } else {
            std.log.debug("Got Method {s}", .{requestHeader.value.method});
        }
    }
}
