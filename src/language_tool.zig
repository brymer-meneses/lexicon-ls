const std = @import("std");
const lsp = @import("lsp/lsp.zig");
const rpc = @import("../rpc.zig");

const GenericParser = @import("parser.zig").GenericParser;
const LineGroup = @import("text_document.zig").LineGroup;
const Line = @import("text_document.zig").Line;
const Language = @import("text_document.zig").Language;
const TextDocument = @import("text_document.zig").TextDocument;

pub const LanguageTool = struct {
    process: ?std.process.Child = null,
    allocator: std.mem.Allocator,
    client: std.http.Client,
    port: u16 = 0,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .client = std.http.Client{ .allocator = allocator },
            .allocator = allocator,
        };
    }

    pub fn start(self: *Self, java_path: []const u8, languagetool_path: []const u8, comptime port: u16) !void {
        if (self.process == null) {
            self.port = port;

            self.process = std.process.Child.init(&.{
                java_path,
                "-cp",
                "languagetool-server.jar",
                "org.languagetool.server.HTTPServer",
                "--config",
                "server.properties",
                "--port",
                std.fmt.comptimePrint("{d}", .{port}),
                "--allow-origin",
            }, self.allocator);
            self.process.?.cwd = languagetool_path;
            try self.process.?.spawn();
        }
    }

    pub fn deinit(self: *Self) !void {
        if (self.process) |*process| {
            _ = try process.kill();
        }

        self.client.deinit();
    }

    pub fn getDiagnostics(self: *Self, doc: *TextDocument) ![]const lsp.types.Diagnostic {
        const url = try std.fmt.allocPrint(self.allocator, "http://localhost:{d}/v2/check", .{self.port});
        defer self.allocator.free(url);

        var response_storage = std.ArrayList(u8).init(self.allocator);
        defer response_storage.deinit();

        var payload_storage = std.ArrayList(u8).init(self.allocator);
        defer payload_storage.deinit();

        var diagnostics = std.ArrayList(lsp.types.Diagnostic).init(self.allocator);
        defer diagnostics.deinit();

        const line_groups = try doc.lineGroups();
        defer doc.allocator.free(line_groups);

        for (line_groups) |line_group| {
            const text = try line_group.contents(self.allocator);
            defer self.allocator.free(text);

            try encodeParams(
                .{
                    .language = "en-US",
                    .text = text,
                },
                payload_storage.writer(),
            );

            const fetch_result = try self.client.fetch(.{
                .method = .POST,
                .server_header_buffer = null,
                .payload = payload_storage.items,
                .location = .{ .url = url },
                .response_storage = .{
                    .dynamic = &response_storage,
                },
            });

            switch (fetch_result.status) {
                .ok => {},
                else => return error.BadRequest,
            }

            const response = try std.json.parseFromSlice(
                LanguageToolResponse,
                self.allocator,
                response_storage.items,
                .{
                    .allocate = .alloc_if_needed,
                    .ignore_unknown_fields = true,
                },
            );
            defer response.deinit();

            std.log.info("Got matches {d} to: {s}", .{ response.value.matches.len, text });

            for (response.value.matches) |match| {
                const range = match.intoLspRange(&line_group) catch continue;

                try diagnostics.append(lsp.types.Diagnostic{
                    .range = range,
                    .message = try self.allocator.dupe(u8, match.message),
                    .source = try self.allocator.dupe(u8, match.context.text),
                    .severity = .Error,
                });
            }
        }

        return try diagnostics.toOwnedSlice();
    }
};

fn encodeParams(params: anytype, writer: anytype) !void {
    var is_first = true;

    inline for (std.meta.fields(@TypeOf(params))) |field| {
        if (is_first) {
            is_first = false;
        } else {
            try writer.writeAll("&");
        }

        try writer.print("{%}={%}", .{
            std.Uri.Component{ .raw = field.name },
            std.Uri.Component{ .raw = @field(params, field.name) },
        });
    }
}

const LanguageToolResponse = struct {
    matches: []const Match,

    pub const Match = struct {
        message: []const u8,
        shortMessage: []const u8,
        offset: u64,
        length: u64,
        replacements: []struct {
            value: []const u8,
        },
        context: struct {
            text: []const u8,
            offset: u64,
            length: u64,
        },
        sentence: []const u8,
        rule: struct {
            id: []const u8,
            subId: ?[]const u8 = null,
            description: []const u8,
            urls: ?[]struct {
                value: []const u8,
            } = null,
            issueType: []const u8,
            category: struct {
                id: []const u8,
                name: []const u8,
            },
        },

        // we only feed stripped contents to `LanguageTool` that's why we need to translate these
        // positions to unstripped contents
        fn intoLspRange(self: *const @This(), line_group: *const LineGroup) !lsp.types.Range {
            var total_offset: u64 = 0;
            const delimiter = line_group.delimiter;

            for (line_group.lines) |line| {
                const strippedContentLength = line.contentsWithoutDelimiter(delimiter).len;

                if (total_offset <= self.offset and self.offset < total_offset + strippedContentLength) {
                    const comment_offset = switch (delimiter) {
                        .double => {
                            @panic("unimplemented");
                        },
                        .single => |delim| delim.len,
                    };

                    const start = self.offset - total_offset + line.column + comment_offset;
                    return lsp.types.Range{
                        .start = .{
                            .line = line.number,
                            .character = start,
                        },
                        .end = .{
                            .line = line.number,
                            .character = start + self.length,
                        },
                    };
                }
                total_offset += strippedContentLength;
            }

            return error.OffsetNotWithinRange;
        }
    };
};

fn initEmptyMatch(offset: u64, length: u64) LanguageToolResponse.Match {
    return .{
        .shortMessage = undefined,
        .message = undefined,
        .replacements = undefined,
        .context = undefined,
        .rule = undefined,
        .sentence = undefined,
        .offset = offset,
        .length = length,
    };
}

test "LanguageToolResponse.Match.intoLspRange" {
    const allocator = std.testing.allocator;
    const source =
        \\ // the quick brown fox jumped
        \\ // over the lazy cat
    ;

    var document = TextDocument.init(allocator, Language.C);
    defer document.deinit();

    var parser = GenericParser(&.{
        .{
            .single = "// ",
        },
    }).init(source, &document);

    try parser.parse();

    const line_groups = try document.lineGroups();
    defer document.allocator.free(line_groups);

    try std.testing.expectEqual(line_groups.len, 1);

    const matches: []const LanguageToolResponse.Match = &.{
        initEmptyMatch(0, 2),
        initEmptyMatch(10, 4),
    };

    const expected_ranges: []const lsp.types.Range = &.{
        .{
            .start = .{
                .line = 0,
                .character = 4,
            },
            .end = .{
                .line = 0,
                .character = 6,
            },
        },
        .{
            .start = .{
                .line = 0,
                .character = 14,
            },
            .end = .{
                .line = 0,
                .character = 18,
            },
        },
    };

    const line_group = line_groups[0];

    for (matches, expected_ranges) |match, expected| {
        const got = try match.intoLspRange(&line_group);
        try std.testing.expectEqual(expected, got);
    }
}
