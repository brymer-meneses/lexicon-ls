const std = @import("std");
const text_document = @import("text_document.zig");

const Language = text_document.Language;

pub const extensionToLanguage = std.StaticStringMap(Language).initComptime(
    .{
        .{ .key = ".cpp", .value = Language.@"C++" },
        .{ .key = ".c", .value = Language.C },
        .{ .key = ".zig", .value = Language.Zig },
        .{ .key = ".rs", .value = Language.Rust },
        .{ .key = ".py", .value = Language.Python },
    },
);

pub fn parse(_: std.mem.Allocator, _: []const u8, uri: []const u8) !bool {
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

    return null;
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
            last_line: u64,
        },

        const Self = @This();

        pub fn parse(self: *Self) void {
            while (!self.isAtEnd()) {
                self.position.start = self.position.current;

                if (self.advance()) |c| {
                    if (c == '\n') {
                        self.position.line += 1;
                        self.position.last_line = self.position.current - 1;
                        continue;
                    }

                    switch (self.delimiters) {
                        .single => |delim| {
                            if (self.match(delim)) {
                                while (self.advance()) |_| {
                                    // if (c1 == '\n') {
                                    //     // self.document.addLine(line: Line);
                                    // }
                                }
                            }
                        },
                        .double => |_| {},
                    }
                }
            }
        }

        pub fn init(source: []const u8) Self {
            return .{
                .source = source,
                .position = .{
                    .start = 0,
                    .current = 0,
                    // the lsp spec wants 0 indexed line
                    .line = 0,
                    .last_line = 0,
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
                return true;
            }

            return false;
        }

        fn advance(self: *Self) ?u8 {
            if (self.isAtEnd())
                return null;

            const c = self.source[self.state.current];
            self.position.current += 1;
            return c;
        }

        fn isAtEnd(self: *const Self) bool {
            return self.position.current + 1 >= self.source.len;
        }
    };
}

// test parse {
//     const source =
//         \\ // This is a very important function
//         \\ // and this is an important documentation
//         \\ u64 fib(u64 n) {
//         \\  if (n <= 1)
//         \\    return 1;
//         \\
//         \\  // fun fact:
//         \\  // this function has an algorithm that is O(1)
//         \\  // it was discovered a long time ago.
//         \\  return fib(n-1) + fib(n-2);
//         \\ }
//     ;
//
//     var doc = try parse(std.testing.allocator, source, "fib.cpp");
//     defer doc.?.deinit();
//     var blockIter = doc.?.iter();
//
//     const firstDoc = try blockIter.next().?.intoText(std.testing.allocator);
//     defer std.testing.allocator.free(firstDoc);
//
//     const secondDoc = try blockIter.next().?.intoText(std.testing.allocator);
//     defer std.testing.allocator.free(secondDoc);
//
//     try std.testing.expectEqualStrings(firstDoc, " This is a very important function and this is an important documentation");
//     try std.testing.expectEqualStrings(secondDoc, " fun fact: this function has an algorithm that is O(1) it was discovered a long time ago.");
// }
//
