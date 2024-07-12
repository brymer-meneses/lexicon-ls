const std = @import("std");

const Delimiter = @import("parser.zig").Delimiters;

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
    contents: []const u8,
};

pub const LineGroup = struct {
    lines: []Line,
    delimiter: Delimiter,

    pub fn contents(self: *@This(), allocator: std.mem.Allocator) []const u8 {
        const arrayList = std.ArrayList(u8).init(allocator);
        defer arrayList.deinit();

        for (self.lines) |line| {
            arrayList.appendSlice(line.contents);
        }

        return arrayList.toOwnedSlice();
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

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .lines = std.ArrayList(Line).init(allocator),
        };
    }
};

test TextDocument {}
