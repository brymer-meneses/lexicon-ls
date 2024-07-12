const std = @import("std");
const text_document = @import("text_document.zig");

const Line = text_document.Line;
const LineGroup = text_document.Line;
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

pub fn GenericParser(comptime delimiters: Delimiter) type {
    return struct {
        comptime delimiter: Delimiter = delimiters,
        source: []const u8,
        position: struct {
            current: u64,
            start: u64,
            line: u64,
            column: u64,
        },

        const Self = @This();

        const Result = union(enum) {
            line: Line,
            group: LineGroup,
        };

        pub fn parse(self: *Self) ?Result {
            while (!self.isAtEnd()) {
                self.position.start = self.position.current;

                if (self.advance()) |c| {
                    if (c == '\n') {
                        self.position.line += 1;
                        self.position.column = 0;
                        continue;
                    }

                    switch (self.delimiter) {
                        .single => |delim| {
                            if (self.match(delim)) {
                                while (self.advance()) |c1| {
                                    if (c1 == '\n') {
                                        return .{
                                            .line = .{
                                                .number = self.position.line,
                                                .column = self.position.column,
                                                .contents = self.source[self.position.start + delim.len + 1 .. self.position.current - 1],
                                            },
                                        };
                                    }
                                }
                            }
                        },
                        .double => |delim| {
                            if (self.match(delim.start)) {
                                while (self.advance()) |c1| {
                                    if (self.match(delim.end)) {
                                        return .{

                                        }
                                    }
                                }
                            }
                        },
                    }
                }
            }

            return null;
        }

        pub fn init(source: []const u8) Self {
            return .{
                .source = source,
                .position = .{
                    .start = 0,
                    .current = 0,
                    // the lsp spec wants 0 indexed line
                    .line = 0,
                    .column = 0,
                },
            };
        }

        fn peekMatch(self: *const Self, comptime value: []const u8) bool {
            if (self.position.current + value.len >= self.source.len) {
                return false;
            }

            const slice = self.source[self.position.current .. self.position.current + value.len];

            if (std.mem.eql(u8, slice, value)) {
                return true;
            }

            return false;
        }

        fn match(self: *Self, comptime value: []const u8) bool {
            if (self.peekMatch(value)) {
                self.position.current += value.len;
                self.position.column += value.len;
                return true;
            }

            return false;
        }

        fn advance(self: *Self) ?u8 {
            if (self.isAtEnd())
                return null;

            const c = self.source[self.position.current];
            self.position.current += 1;
            self.position.column += 1;
            return c;
        }

        fn isAtEnd(self: *const Self) bool {
            return self.position.current + 1 >= self.source.len;
        }
    };
}

test "GenericParser Single Delimiter" {
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

    var parser = GenericParser(.{ .single = "// " }).init(source);
    try std.testing.expectEqualStrings("This is a very important function", parser.parse().?.contents);
    try std.testing.expectEqualStrings("and this is an important documentation", parser.parse().?.contents);
    try std.testing.expectEqualStrings("fun fact:", parser.parse().?.contents);
    try std.testing.expectEqualStrings("this function has an algorithm that is O(1)", parser.parse().?.contents);
    try std.testing.expectEqualStrings("it was discovered a long time ago.", parser.parse().?.contents);
}

test "GenericParser Double Delimiter" {
    const source =
        \\ def some_important_function():
        \\ """"
        \\ The quick brown fox
        \\ jumped over the lazy cat
        \\ """"
    ;

    _ = GenericParser(
        .{
            .double = .{
                .start = "\"\"\"",
                .end = "\"\"\"",
            },
        },
    ).init(source);
}
