const std = @import("std");
const lsp = @import("lsp/lsp.zig");

const Delimiter = @import("parser.zig").Delimiter;

pub const Language = enum {
    @"C++",
    C,
    Zig,
    Rust,
    Python,
};

pub const Line = struct {
    /// line number
    number: u64,
    /// starting offset in the line
    column: u64,

    /// contents of the line we only care about
    /// this is an owned copy of a string
    ///
    /// example:
    /// ```cpp
    /// // hi there
    /// ```
    contents: []const u8,

    const Self = @This();

    pub fn contentsWithoutDelimiter(self: *const Self, delimiter: Delimiter) []const u8 {
        return switch (delimiter) {
            .single => |delim| self.contents[delim.len..],
            .double => {
                @panic("Unimpemented");
            },
        };
    }
};

pub const LineGroup = struct {
    lines: []const Line,
    delimiter: Delimiter,

    const Self = @This();

    pub fn init(lines: []const Line, delimiter: Delimiter) Self {
        return .{ .lines = lines, .delimiter = delimiter };
    }

    pub fn contents(self: *const Self, allocator: std.mem.Allocator) ![]const u8 {
        var text = std.ArrayList(u8).init(allocator);
        defer text.deinit();

        for (self.lines) |line| {
            try text.appendSlice(line.contentsWithoutDelimiter(self.delimiter));
        }

        return text.toOwnedSlice();
    }
};

/// `TextDocument` is the internal representation of a source file
///
/// **NOTE**
/// We only keep track of the necessary portions of a source
/// file we do not bother with keeping track of things that are not considered
/// documentation
pub const TextDocument = struct {
    lines: std.ArrayList(Line),
    line_group_descriptors: std.ArrayList(LineGroupDescriptor),
    language: Language,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, language: Language) Self {
        return .{
            .lines = std.ArrayList(Line).init(allocator),
            .line_group_descriptors = std.ArrayList(LineGroupDescriptor).init(allocator),
            .allocator = allocator,
            .language = language,
        };
    }

    pub fn deinit(self: *Self) void {
        self.lines.deinit();
        self.line_group_descriptors.deinit();
    }

    pub fn lineGroups(self: *Self) ![]const LineGroup {
        const num = self.line_group_descriptors.items.len;
        var line_groups = try std.ArrayList(LineGroup).initCapacity(self.allocator, num);
        defer line_groups.deinit();

        for (self.line_group_descriptors.items) |line_group_descriptor| {
            const start = self.indexOfLineNumber(line_group_descriptor.start).?;
            const end = self.indexOfLineNumber(line_group_descriptor.end).?;

            const line_group = LineGroup{
                .delimiter = line_group_descriptor.delimiter,
                .lines = self.lines.items[start .. end + 1],
            };
            try line_groups.append(line_group);
        }

        return line_groups.toOwnedSlice();
    }

    pub fn addLine(self: *Self, delimiter: Delimiter, line: Line) !void {
        var hasBeenAbsorbed = false;

        for (self.line_group_descriptors.items) |*group| {
            if (group.absorbIfPossible(delimiter, line.number)) {
                hasBeenAbsorbed = true;
            }
        }

        if (!hasBeenAbsorbed) {
            try self.line_group_descriptors.append(LineGroupDescriptor{
                .delimiter = delimiter,
                .start = line.number,
                .end = line.number,
            });
        }

        try self.lines.append(line);
    }

    fn indexOfLineNumber(self: *Self, num: u64) ?u64 {
        for (self.lines.items, 0..) |line, i| {
            if (line.number == num) return i;
        }

        return null;
    }
};

const LineGroupDescriptor = struct {
    /// starting line of the line group
    start: u64,
    /// ending line of the line group
    end: u64,
    delimiter: Delimiter,

    fn absorbIfPossible(self: *@This(), delimiter: Delimiter, num: u64) bool {
        if (!std.meta.eql(self.delimiter, delimiter)) return false;

        // is within range
        if (self.start < num and num < self.end) return true;

        if (self.start > 0 and self.start - 1 == num) {
            self.start = num;
            return true;
        }

        if (self.end + 1 == num) {
            self.end = num;
            return true;
        }

        return false;
    }
};
test "TextDocument.LineGroup.absorbIfPossible" {
    var line_group_descriptor = LineGroupDescriptor{
        .start = 0,
        .end = 0,
        .delimiter = .{ .single = "// " },
    };

    const hasBeenAbsorbed = line_group_descriptor.absorbIfPossible(.{ .single = "// " }, 1);

    try std.testing.expectEqual(true, hasBeenAbsorbed);
    try std.testing.expectEqual(1, line_group_descriptor.end);
}

test "TextDocument.addLine" {
    const allocator = std.testing.allocator;
    var document = TextDocument.init(allocator, Language.@"C++");
    defer document.deinit();

    try document.addLine(.{ .single = "// " }, Line{
        .number = 0,
        .column = 0,
        .contents = "The quick brown",
    });

    try document.addLine(.{ .single = "// " }, Line{
        .number = 1,
        .column = 0,
        .contents = "fox jumped over the lazy cat.",
    });

    try std.testing.expectEqual(1, document.line_group_descriptors.items.len);
}
