const std = @import("std");
const TextDocument = @import("../text_document.zig").TextDocument;

pub const Parser = struct {
    const Self = @This();

    source: []const u8,
    filename: []const u8,
    allocator: std.mem.Allocator,

    state: struct {
        current: u64,
        start: u64,
        line: u64,
    },

    pub fn init(allocator: std.mem.Allocator, source: []const u8, filename: []const u8) Self {
        return .{
            .allocator = allocator,
            .source = source,
            .filename = filename,
            .state = .{
                .start = 0,
                .current = 0,
                .line = 1,
            },
        };
    }

    pub fn parse(self: *Self) !?TextDocument {
        var document = TextDocument.init(self.allocator, self.filename);

        while (!self.isAtEnd()) {
            self.state.start = self.state.current;

            if (self.advance()) |c| {
                switch (c) {
                    '\n' => {
                        self.state.line += 1;
                    },
                    '/' => {
                        if (self.advance() != '/') {
                            continue;
                        }

                        while (self.advance()) |c1| {
                            if (c1 == '\n') break;
                        }

                        self.state.current -= 1;

                        try document.addLine(.{
                            .line_offset = self.state.current,
                            .line = self.state.line,
                            .contents = self.source[self.state.start + 2 .. self.state.current],
                        });
                    },
                    else => {},
                }
            }
        }

        return document;
    }

    fn advance(self: *Self) ?u8 {
        if (self.isAtEnd())
            return null;

        const c = self.source[self.state.current];
        self.state.current += 1;
        return c;
    }

    inline fn isAtEnd(self: *const Self) bool {
        return self.state.current + 1 >= self.source.len;
    }
};

test "parse cpp" {
    const source =
        \\ // some comment
        \\ auto fib(u64 num) -> u64 {
        \\   if (num <= 10) {
        \\      return 1;
        \\   } 
        \\
        \\   // another comment
        \\   return fibonacci(num - 1) + fibonacci(num - 2);
        \\ }
    ;

    const allocator = std.testing.allocator;
    var parser = Parser.init(allocator, source, "file.py");
    var document = try parser.parse();

    try std.testing.expect(document != null);

    defer document.?.deinit();

    const lines = document.?.lines.items;

    try std.testing.expectEqual(lines.len, 2);

    try std.testing.expectEqualStrings(lines[0].contents, " some comment");
    try std.testing.expectEqualStrings(lines[1].contents, " another comment");
}