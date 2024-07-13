const std = @import("std");
const text_document = @import("text_document.zig");

const TextDocument = text_document.TextDocument;
const Line = text_document.Line;
const Language = text_document.Language;

pub const extensionToLanguage = std.StaticStringMap(Language).initComptime(
    &.{
        .{ ".cpp", Language.@"C++" },
        .{ ".c", Language.C },
        .{ ".zig", Language.Zig },
        .{ ".rs", Language.Rust },
        .{ ".py", Language.Python },
    },
);

pub fn parse(_: std.mem.Allocator, _: []const u8, uri: []const u8) !void {
    const extension = std.fs.path.extension(uri);
    const language = extensionToLanguage.get(extension);

    if (language) |lang| {
        switch (lang) {
            .@"C++", .C => {},
            .Python => {},
            .Zig => {},
            .Rust => {},
        }
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

                if (self.advance()) |c| {
                    if (c == '\n') {
                        self.position.line += 1;
                        continue;
                    }

                    for (self.delimiters) |delimiter| {
                        try self.parseDelimiter(delimiter);
                    }
                }
            }
        }

        fn parseDelimiter(self: *Self, delimiter: Delimiter) !void {
            switch (delimiter) {
                .single => |delim| {
                    if (self.match(delim)) {
                        while (self.advance()) |c1| {
                            if (c1 == '\n') {
                                try self.document.addLine(
                                    delimiter,
                                    .{
                                        .number = self.position.line,
                                        .column = self.position.start - self.position.last_line,
                                        .contents = self.source[self.position.start + 1 .. self.position.current],
                                    },
                                );
                                self.position.line += 1;
                                break;
                            }
                        }
                    }
                },
                .double => |delim| {
                    if (self.match(delim.start)) {
                        while (self.advance()) |c1| {
                            if (c1 == '\n') {
                                try self.document.addLine(
                                    delimiter,
                                    .{
                                        .number = self.position.line,
                                        .column = self.position.start - self.position.last_line,
                                        .contents = self.source[self.position.start + 1 .. self.position.current],
                                    },
                                );
                                self.position.line += 1;
                            }

                            if (self.match(delim.end)) {
                                try self.document.addLine(
                                    delimiter,
                                    .{
                                        .number = self.position.line,
                                        .column = self.position.start - self.position.last_line,
                                        .contents = self.source[self.position.start + 1 .. self.position.current],
                                    },
                                );
                                self.position.line += 1;
                                break;
                            }
                        }
                    }
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
        \\ // This is a very important function
        \\ // and this is an important documentation
        \\ u64 fib(u64 n) {
        \\  if (n <= 1)
        \\    return 1;
        \\
        \\  // fun fact:
        \\  // this function has an algorithm that is O(1)
        \\  // it was discovered a long time ago.
        \\  return fib(n-1) + fib(n-2);
        \\ }
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

    for (line_groups, expectedStrings) |line_group, expected| {
        const contents = try line_group.contents(allocator);
        defer allocator.free(contents);

        try std.testing.expectEqualStrings(expected, contents);
    }
}

test "GenericParser Double Delimiter" {}
