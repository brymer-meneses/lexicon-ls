const std = @import("std");

const TextDocument = @import("../TextDocument.zig");
const Line = TextDocument.Line;

const Language = enum {
    cpp,
    c,
    zig,
    python,
    markdown,
    rust,
};

pub fn parse(allocator: std.mem.Allocator, source: []const u8, filename: []const u8) !?TextDocument {
    if (parseLanguageFromFilename(filename)) |language| {
        switch (language) {
            .python => {
                return null;
            },
            .c, .cpp => {
                const Parser = @import("cpp.zig").Parser;
                var parser = Parser.init(allocator, source, filename);
                return try parser.parse();
            },
            .zig => {
                return null;
            },
            .rust => {
                return null;
            },
            .markdown => {
                return null;
            },
        }
    }
    return null;
}

fn parseLanguageFromFilename(filename: []const u8) ?Language {
    var tokenized = std.mem.tokenizeAny(u8, filename, ".");

    if (tokenized.peek() == null) {
        return null;
    }

    var extension: []const u8 = tokenized.next().?;

    while (tokenized.peek() != null) {
        extension = tokenized.next().?;
    }

    if (std.mem.eql(u8, "py", extension)) {
        return Language.python;
    } else if (std.mem.eql(u8, "zig", extension)) {
        return Language.zig;
    } else if (std.mem.eql(u8, "md", extension)) {
        return Language.markdown;
    } else if (std.mem.eql(u8, "cpp", extension)) {
        return Language.cpp;
    } else if (std.mem.eql(u8, "c", extension)) {
        return Language.c;
    }

    return null;
}

test parseLanguageFromFilename {
    const filenames: []const []const u8 = &.{ "hello_world.py", "awesome_file.zig", "readme.md" };
    const languages: []const Language = &.{ Language.python, Language.zig, Language.markdown };

    for (filenames, languages) |filename, language| {
        const parsed_language = parseLanguageFromFilename(filename);

        try std.testing.expect(parsed_language != null);
        try std.testing.expectEqual(parsed_language.?, language);
    }
}

test parse {
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

    var doc = try parse(std.testing.allocator, source, "fib.cpp");
    defer doc.?.deinit();
    var blockIter = doc.?.iter();

    const firstDoc = try blockIter.next().?.intoText(std.testing.allocator);
    defer std.testing.allocator.free(firstDoc);

    const secondDoc = try blockIter.next().?.intoText(std.testing.allocator);
    defer std.testing.allocator.free(secondDoc);

    try std.testing.expectEqualStrings(firstDoc, " This is a very important function and this is an important documentation");
    try std.testing.expectEqualStrings(secondDoc, " fun fact: this function has an algorithm that is O(1) it was discovered a long time ago.");
}

test {
    std.testing.refAllDecls(@import("python.zig"));
    std.testing.refAllDecls(@import("cpp.zig"));
}
