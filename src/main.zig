const std = @import("std");
const lsp = @import("lsp/lsp.zig");
const rpc = @import("rpc.zig");

pub const std_options = .{
    .logFn = @import("log.zig").log,
};

const helpMessage =
    \\ An open-source grammar-checker that uses LanguageTool
    \\ 
    \\ Usage [command] [options]
    \\ 
    \\ Commands:
    \\
    \\      lsp         run as an LSP server
    \\      lint        run as a linter
    \\      setup       download languageTool and Java
    \\  
    \\      help        print this help message and exit
    \\      version     print version number and exit
;

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    // Parse args into string array (error union needs 'try')
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len <= 1) {
        std.debug.print(helpMessage, .{});
        return;
    }

    const command = args[1];

    if (std.mem.eql(u8, command, "help")) {
        std.debug.print(helpMessage, .{});
    } else if (std.mem.eql(u8, command, "version")) {
        std.debug.print("0.0.1", .{});
    } else if (std.mem.eql(u8, command, "setup")) {
        std.debug.print("TODO", .{});
    } else if (std.mem.eql(u8, command, "lsp")) {
        try lspMain(allocator, args[2..]);
    } else if (std.mem.eql(u8, command, "lint")) {
        try lintMain(allocator, args[2..]);
    } else {
        std.debug.print(helpMessage, .{});
    }
}

pub fn lspMain(allocator: std.mem.Allocator, _: []const []const u8) anyerror!void {
    std.debug.print("Entering LSP main\n", .{});

    const stdin = std.io.getStdIn();
    const stdout = std.io.getStdOut();
    var buf = std.io.bufferedReader(stdin.reader());

    const reader = buf.reader();
    const writer = stdout.writer();

    const jsonOptions = .{
        .ignore_unknown_fields = true,
        .allocate = .alloc_always,
    };

    var server = lsp.server(allocator, writer, reader);

    while (true) {
        const content = try rpc.receive(allocator, reader);
        defer allocator.free(content);

        const requestHeader = try std.json.parseFromSlice(
            lsp.types.RequestHeader,
            allocator,
            content,
            jsonOptions,
        );
        defer requestHeader.deinit();

        const method = requestHeader.value.method;

        if (std.mem.eql(u8, method, "initialize")) {
            // TODO: gracefully handle initialization errors
            const request = try std.json.parseFromSlice(
                struct { params: lsp.types.InitializeRequestParams },
                allocator,
                content,
                jsonOptions,
            );
            defer request.deinit();

            try server.initialize(requestHeader.value, request.value.params);
        } else if (std.mem.eql(u8, method, "initialized")) {
            std.log.debug("Successfully initialized with client!", .{});
        } else if (std.mem.eql(u8, method, "shutdown")) {
            try server.shutdown();
            break;
        } else if (std.mem.eql(u8, method, "textDocument/didOpen")) {
            const request = try std.json.parseFromSlice(
                struct { params: lsp.types.DidOpenTextDocumentParams },
                allocator,
                content,
                jsonOptions,
            );
            defer request.deinit();

            try server.textDocumentDidOpen(request.value.params);
        } else if (std.mem.eql(u8, method, "textDocument/didChange")) {
            const request = try std.json.parseFromSlice(
                struct { params: lsp.types.DidChangeTextDocumentParams },
                allocator,
                content,
                jsonOptions,
            );
            defer request.deinit();

            try server.textDocumentDidChange(request.value.params);
        } else {
            std.log.debug("Got Method {s}", .{method});
        }
    }
}

pub fn lintMain(_: std.mem.Allocator, _: []const []const u8) anyerror!void {
    std.debug.print("Entering lint main\n", .{});
}

test {
    std.testing.refAllDecls(rpc);
}
