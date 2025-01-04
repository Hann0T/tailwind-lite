const std = @import("std");

pub fn main() !void {
    // build allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const check = gpa.deinit();
        switch (check) {
            .leak => std.debug.print("memory leak\n", .{}),
            .ok => {},
        }
    }

    // Alloc args
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len <= 1) {
        std.debug.print("{s} <file>", .{args[0]});
        return error.InvalidArgs;
    }

    const filename = args[1];
    const file = std.fs.cwd().openFile(filename, .{ .mode = .read_only }) catch |err| {
        std.log.err("{s}, trying to open a file.", .{@errorName(err)});
        return;
    };
    var reader = file.reader();

    var buf: [4096]u8 = undefined;
    while (reader.readUntilDelimiterOrEof(&buf, '\n') catch |err| {
        std.log.err("{s}, trying to read a file.", .{@errorName(err)});
        return;
    }) |line| {
        const trimed = std.mem.trim(u8, line, " ");
        const optinal = classes_from_line(allocator, trimed);
        if (optinal) |classes| {
            defer allocator.free(classes);
            std.debug.print("classes: {s}\n", .{classes});
        }
    }
}

fn classes_from_line(allocator: std.mem.Allocator, line: []const u8) ?[][]const u8 {
    const needle = "class=\"";
    const index = std.mem.indexOf(u8, line, needle);
    if (index == null) return null;

    const start_index: usize = index.? + needle.len;
    var closing_index: usize = 0;

    for (line[start_index..line.len], start_index..) |char, i| {
        if (char == '"') {
            closing_index = i;
            break;
        }
    }

    var list = std.ArrayList([]const u8).init(allocator);
    defer list.deinit();

    var items = std.mem.tokenizeScalar(u8, line[start_index..closing_index], ' ');
    while (items.next()) |token| {
        list.append(token) catch {
            return null;
        };
    }

    return list.toOwnedSlice() catch {
        return null;
    };
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
