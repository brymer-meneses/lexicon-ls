const std = @import("std");
const Range = @import("lsp/types.zig").Range;

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
    number: u64,
    offset: u64,
};

/// A block is a contiguous collection of lines that can make up a line,
/// paragraph or multiple paragraphs
pub const Block = struct {
    lines: []const Line,

    pub const Error = error{
        OffsetNotWithinRange,
    };

    pub fn init(lines: []const Line) Block {
        return .{ .lines = lines };
    }

    pub fn translateOffsetAndLength(self: *const Block, offset: u64, length: u64) Error!Range {
        var block_offset: u64 = 0;

        for (self.lines) |line| {
            if (block_offset <= offset and offset < block_offset + line.contents.len) {
                const start = offset - block_offset + line.offset;
                return Range{
                    .start = .{
                        .line = line.number,
                        .character = start,
                    },
                    .end = .{
                        .line = line.number,
                        .character = start + length,
                    },
                };
            }
            block_offset += line.contents.len;
        }

        return Error.OffsetNotWithinRange;
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

            if (next_line.number == current_line.number + 1) {
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
        .{ .contents = "", .number = 1, .offset = 0 },
        .{ .contents = "", .number = 2, .offset = 0 },
        .{ .contents = "", .number = 3, .offset = 0 },

        .{ .contents = "", .number = 5, .offset = 0 },

        .{ .contents = "", .number = 10, .offset = 0 },
        .{ .contents = "", .number = 11, .offset = 0 },
        .{ .contents = "", .number = 12, .offset = 0 },
    };

    var iterator = BlockIterator.init(lines);

    try std.testing.expectEqualSlices(Line, lines[0..3], iterator.next().?.lines);
    try std.testing.expectEqualSlices(Line, lines[3..4], iterator.next().?.lines);
    try std.testing.expectEqualSlices(Line, lines[4..7], iterator.next().?.lines);

    try std.testing.expectEqual(null, iterator.next());
}
