const std = @import("std");
const usage =
    \\Usage: ./extract_build_params [options]
    \\
    \\Options:
    \\  --cmake-lists CMakeLists.txt_FILE
    \\  --params-zig params.zig_FILE
    \\
;

const State = enum {
    lines,
    sources,
};

pub fn main() !void {
    var arena_state = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const args = try std.process.argsAlloc(arena);

    var opt_in_file_path: ?[]const u8 = null;
    var opt_out_file_path: ?[]const u8 = null;
    {
        var i: usize = 1;
        while (i < args.len) : (i += 1) {
            const arg = args[i];
            if (std.mem.eql(u8, "-h", arg) or std.mem.eql(u8, "--help", arg)) {
                try std.io.getStdOut().writeAll(usage);
                return std.process.cleanExit();
            } else if (std.mem.eql(u8, "--cmake-lists", arg)) {
                i += 1;
                if (i > args.len) fatal("expected arg after '{s}'", .{arg});
                if (opt_in_file_path != null) fatal("duplicated {s} argument", .{arg});
                opt_in_file_path = args[i];
            } else if (std.mem.eql(u8, "--params-zig", arg)) {
                i += 1;
                if (i > args.len) fatal("expected arg after '{s}'", .{arg});
                if (opt_out_file_path != null) fatal("duplicated {s} argument", .{arg});
                opt_out_file_path = args[i];
            } else {
                fatal("unrecognized arg: '{s}', i:{d}, args.len:{d}", .{ arg, i, args.len });
            }
        }
    }

    const in_file_path = opt_in_file_path orelse fatal("missing --cmake-lists", .{});
    const out_file_path = opt_out_file_path orelse fatal("missing --params-zig", .{});
    // allocate a large enough buffer to store the cwd
    var buf: [std.fs.max_path_bytes]u8 = undefined;

    // getcwd writes the path of the cwd into buf and returns a slice of buf with the len of cwd
    const cwd = try std.process.getCwd(&buf);

    // print out the cwd
    //    std.debug.print("cwd: {s}\n", .{cwd});
    //std.debug.print("input file:{s}\n", .{in_file_path});
    var in_file = std.fs.cwd().openFile(in_file_path, .{}) catch |err| {
        fatal("unable to open '{s}': {s}, cwd:{s}", .{ in_file_path, @errorName(err), cwd });
    };
    defer in_file.close();
    var out_file = std.fs.cwd().createFile(out_file_path, .{}) catch |err| {
        fatal("unable to open '{s}': {s}, cwd:{s}", .{ out_file_path, @errorName(err), cwd });
    };
    defer out_file.close();

    var buf_reader = std.io.bufferedReader(in_file.reader());
    const reader = buf_reader.reader();

    const writer = out_file.writer();

    var line = std.ArrayList(u8).init(arena);
    defer line.deinit();

    const line_writer = line.writer();
    var line_no: usize = 0;

    var state = State.lines;
    var sources_written: bool = false;
    while (reader.streamUntilDelimiter(line_writer, '\n', null)) {
        // Clear the line so we can reuse it.
        defer line.clearRetainingCapacity();
        line_no += 1;
        //
        if (state == State.lines) {
            if (std.mem.startsWith(u8, line.items, "set(toxcore_SOURCES")) {
                state = State.sources;
                if (!sources_written) {
                    try writer.writeAll(
                        \\pub const c_sources = &.{
                    );
                    sources_written = true;
                }
            }
        } else if (state == State.sources) {
            var trimmed = std.mem.trim(u8, line.items, " \t,");
            if (std.mem.endsWith(u8, trimmed, ")")) {
                trimmed = trimmed[0 .. trimmed.len - 1];
                state = State.lines; // end of sources
            }
            if (std.mem.endsWith(u8, trimmed, ".c")) {
                try writer.print("    \"{s}\",\n", .{trimmed});
                //std.debug.print("{d}--{s}\n", .{ line_no, trimmed });
            }
        }
    } else |err| switch (err) {
        error.EndOfStream => {}, // end of file
        else => return err, // Propagate error
    }
    if (sources_written) try writer.writeAll("};\n");
}
fn fatal(comptime format: []const u8, args: anytype) noreturn {
    std.debug.print(format, args);
    std.process.exit(1);
}
