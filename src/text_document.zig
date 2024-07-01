const std = @import("std");

pub const TextDocument = struct {
    allocator: std.heap.ArenaAllocator,
    lines: std.MultiArrayList(Line),
    uri: []const u8,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, uri: []const u8) Self {
        return .{
            .allocator = std.heap.ArenaAllocator.init(allocator),
            .lines = std.MultiArrayList(Line){},
            .uri = uri,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.deinit();
    }

    pub fn collectText(_: *Self) []const u8 {
        return "";
    }
};

pub const Line = struct {
    line: u64,
    text: []const u8,
};
