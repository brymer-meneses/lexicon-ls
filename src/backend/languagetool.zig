const std = @import("std");

pub fn spawnServer(allocator: std.mem.Allocator, java_path: []const u8, languagetool_path: []const u8) std.process.Child.SpawnError!void {
    var process = std.process.Child.init(
        &[_][]const u8{
            java_path,
            "-cp",
            "languagetool-server.jar",
            "org.languagetool.server.HTTPServer",
            "--config",
            "server.properties",
            "--port",
            "8081",
            "--allow-origin",
        },
        allocator,
    );

    process.cwd = languagetool_path;

    try process.spawn();

    std.log.debug("Successfully spawned languagetool server thread\n", .{});

    _ = try process.wait();
}
