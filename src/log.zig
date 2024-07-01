const std = @import("std");
const fs = std.fs;

const lexicon_logfile = ".cache/lexicon/log.txt";

pub fn log(
    comptime level: std.log.Level,
    comptime _: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var env_map = std.process.getEnvMap(allocator) catch |err| {
        std.debug.panic("Encountered error {any}\n", .{err});
    };
    defer env_map.deinit();

    const home = env_map.get("HOME") orelse {
        std.debug.panic("Failed to read $HOME.\n", .{});
    };

    const path = std.fs.path.join(allocator, &.{ home, lexicon_logfile }) catch |err| {
        std.debug.panic("Encountered error {any}\n", .{err});
    };
    defer allocator.free(path);

    const file = fs.createFileAbsolute(path, .{ .truncate = false }) catch |err| {
        std.debug.panic("{any}", .{err});
    };
    defer file.close();

    const stat = file.stat() catch |err| {
        std.debug.panic("Failed to get stat of log file: {}\n", .{err});
    };
    file.seekTo(stat.size) catch |err| {
        std.debug.panic("{any}", .{err});
    };

    const prefix = "[" ++ comptime level.asText() ++ "]: ";

    const message = std.fmt.allocPrint(allocator, prefix ++ format ++ "\n", args) catch |err| {
        std.debug.panic("Failed to format log message with args: {}\n", .{err});
    };
    defer allocator.free(message);

    file.writeAll(message) catch |err| {
        std.debug.panic("Failed to write to log file: {}\n", .{err});
    };
}
