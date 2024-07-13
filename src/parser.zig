const std = @import("std");
const text_document = @import("text_document.zig");

const TextDocument = text_document.TextDocument;
const Line = text_document.Line;
const Language = text_document.Language;

pub fn parse(document: *TextDocument, source: []const u8) !void {
    switch (document.language) {
        .@"C++", .C => {
            var parser = GenericParser(&.{.{ .single = "// " }}).init(source, document);
            try parser.parse();
        },
        .Python => {},
        .Zig => {},
        .Rust => {},
    }
}

pub const Delimiter = union(enum) {
    double: struct {
        start: []const u8,
        end: []const u8,
    },
    single: []const u8,
};

pub fn GenericParser(comptime delimiters: []const Delimiter) type {
    return struct {
        comptime delimiters: []const Delimiter = delimiters,

        source: []const u8,
        position: struct {
            current: u64,
            start: u64,
            line: u64,
            last_line: u64,
        },
        document: *TextDocument,

        const Self = @This();

        pub fn parse(self: *Self) !void {
            while (!self.isAtEnd()) {
                self.position.start = self.position.current;

                for (self.delimiters) |delimiter| {
                    try self.parseDelimiter(delimiter);
                }

                const c = self.advance();
                if (c == '\n') {
                    self.advanceLine();
                }
            }
        }

        fn parseDelimiter(self: *Self, delimiter: Delimiter) !void {
            switch (delimiter) {
                .single => |delim| {
                    while (self.match(delim)) {
                        while (self.advance()) |c| {
                            if (c == '\n') break;
                        }

                        try self.document.addLine(
                            delimiter,
                            .{
                                .number = self.position.line,
                                .column = self.position.start - self.position.last_line,
                                .contents = self.source[self.position.start..self.position.current],
                            },
                        );

                        self.position.start = self.position.current;
                        self.advanceLine();
                    }
                },
                .double => |_| {
                    @panic("Unimplemented");
                },
            }
        }

        pub fn init(source: []const u8, document: *TextDocument) Self {
            return .{
                .source = source,
                .document = document,
                .position = .{
                    .start = 0,
                    .current = 0,
                    // the lsp spec wants 0 indexed line
                    .line = 0,
                    .last_line = 0,
                },
            };
        }

        fn peekMatch(self: *const Self, value: []const u8) bool {
            if (self.position.current + value.len >= self.source.len) {
                return false;
            }

            const slice = self.source[self.position.current .. self.position.current + value.len];

            if (std.mem.eql(u8, slice, value)) {
                return true;
            }

            return false;
        }

        fn match(self: *Self, value: []const u8) bool {
            if (self.peekMatch(value)) {
                self.position.current += value.len;
                return true;
            }

            return false;
        }

        fn peek(self: *const Self) ?u8 {
            if (self.isAtEnd())
                return null;

            return self.source[self.position.current];
        }

        /// advances the metadata for tracking line and column
        fn advanceLine(self: *Self) void {
            self.position.line += 1;
            self.position.last_line = self.position.current;
        }

        fn advance(self: *Self) ?u8 {
            if (self.isAtEnd())
                return null;

            const c = self.source[self.position.current];
            self.position.current += 1;
            return c;
        }

        fn isAtEnd(self: *const Self) bool {
            return self.position.current + 1 >= self.source.len;
        }
    };
}

test "GenericParser Single Delimiter" {
    const allocator = std.testing.allocator;

    const source =
        \\// This is a very important function
        \\// and this is an important documentation
        \\u64 fib(u64 n) {
        \\  if (n <= 1)
        \\    return 1;
        \\
        \\  // fun fact:
        \\  // this function has an algorithm that is O(1)
        \\  // it was discovered a long time ago.
        \\  return fib(n-1) + fib(n-2);
        \\}
    ;

    const delimiters: []const Delimiter = &.{
        .{ .single = "// " },
    };

    var document = TextDocument.init(allocator, Language.@"C++");
    defer document.deinit();

    var parser = GenericParser(delimiters).init(source, &document);
    try parser.parse();

    try std.testing.expectEqual(5, document.lines.items.len);

    const line_groups = try document.lineGroups();
    defer allocator.free(line_groups);

    try std.testing.expectEqual(2, line_groups.len);

    const expectedStrings: []const []const u8 = &.{
        \\This is a very important function
        \\and this is an important documentation
        \\
        ,
        \\fun fact:
        \\this function has an algorithm that is O(1)
        \\it was discovered a long time ago.
        \\
    };

    const expectedLines: []const Line = &.{
        .{
            .number = 0,
            .column = 0,
            .contents = "// This is a very important function\n",
        },
        .{
            .number = 1,
            .column = 0,
            .contents = "// and this is an important documentation\n",
        },
        .{
            .number = 6,
            .column = 2,
            .contents = "// fun fact:\n",
        },
        .{
            .number = 7,
            .column = 2,
            .contents = "// this function has an algorithm that is O(1)\n",
        },
        .{
            .number = 8,
            .column = 2,
            .contents = "// it was discovered a long time ago.\n",
        },
    };

    for (document.lines.items, expectedLines) |line, expected| {
        try std.testing.expectEqualDeep(expected, line);
    }

    for (line_groups, expectedStrings) |line_group, expected| {
        const contents = try line_group.contents(allocator);
        defer allocator.free(contents);

        try std.testing.expectEqualStrings(expected, contents);
    }
}

test "GenericParser Double Delimiter" {}
