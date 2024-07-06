const std = @import("std");

allocator: std.heap.ArenaAllocator,
lines: std.ArrayList(Line),
uri: []const u8,
const Self = @This();

pub fn init(allocator: std.mem.Allocator, uri: []const u8) Self {
    return .{
        .allocator = std.heap.ArenaAllocator.init(allocator),
        .lines = std.ArrayList(Line).init(allocator),
        .uri = uri,
    };
}

pub fn deinit(self: *Self) void {
    self.lines.deinit();
    self.allocator.deinit();
}

pub fn iter(self: *Self) BlockIterator {
    return BlockIterator.init(self.lines.items);
}

pub fn addLine(self: *Self, line: Line) !void {
    try self.lines.append(line);
}

pub const Line = struct {
    contents: []const u8,
    line: u64,
    line_offset: u64,
};

/// A block is a contiguous collection of lines that can make up a line,
/// paragraph or multiple paragraphs
pub const Block = struct {
    lines: []const Line,

    const Self = @This();

    pub fn init(lines: []const Line) Block {
        return .{ .lines = lines };
    }

    pub fn getLineFromOffset(_: *Block, _: u64) ?Line {
        return null;
    }

    pub fn intoText(self: *const Block, allocator: std.mem.Allocator) ![]const u8 {
        var text = std.ArrayList(u8).init(allocator);

        for (self.lines) |line| {
            try text.appendSlice(line.contents);
        }

        return try text.toOwnedSlice();
    }
};

pub const BlockIterator = struct {
    lines: []const Line,
    index: u64,

    const Self = @This();

    pub fn init(lines: []const Line) BlockIterator {
        return .{ .lines = lines, .index = 0 };
    }

    pub fn next(self: *BlockIterator) ?Block {
        if (self.index >= self.lines.len - 1) return null;

        const start = self.index;
        var streak: u64 = 1;

        while (self.index < self.lines.len - 1) {
            const current_line = self.lines[self.index];
            const next_line = self.lines[self.index + 1];

            self.index += 1;

            if (next_line.line == current_line.line + 1) {
                streak += 1;
            } else {
                break;
            }
        }

        return Block.init(self.lines[start..(start + streak)]);
    }
};

test BlockIterator {
    const lines: []const Line = &.{
        .{ .contents = "", .line = 1, .line_offset = 0 },
        .{ .contents = "", .line = 2, .line_offset = 0 },
        .{ .contents = "", .line = 3, .line_offset = 0 },

        .{ .contents = "", .line = 5, .line_offset = 0 },

        .{ .contents = "", .line = 10, .line_offset = 0 },
        .{ .contents = "", .line = 11, .line_offset = 0 },
        .{ .contents = "", .line = 12, .line_offset = 0 },
    };

    var iterator = BlockIterator.init(lines);

    try std.testing.expectEqualSlices(Line, lines[0..3], iterator.next().?.lines);
    try std.testing.expectEqualSlices(Line, lines[3..4], iterator.next().?.lines);
    try std.testing.expectEqualSlices(Line, lines[4..7], iterator.next().?.lines);

    try std.testing.expectEqual(null, iterator.next());
}
