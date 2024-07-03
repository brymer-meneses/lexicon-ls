const std = @import("std");
const text_document = @import("../text_document.zig");

const TextDocument = text_document.TextDocument;
const Line = text_document.Line;

const Language = enum {
    cpp,
    c,
    zig,
    python,
    markdown,
    rust,
};

pub fn parse(_: std.mem.Allocator, _: []const u8, filename: []const u8) !?TextDocument {
    if (parseLanguageFromFilename(filename)) |language| {
        switch (language) {
            .python => {
                return null;
            },
            .c, .cpp => {
                return null;
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

test {
    std.testing.refAllDecls(@import("python.zig"));
    std.testing.refAllDecls(@import("cpp.zig"));
}
