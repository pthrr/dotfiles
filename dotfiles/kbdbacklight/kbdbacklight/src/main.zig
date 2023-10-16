const std = @import("std");
const fs = std.fs;
const os = std.os;
const linux = os.linux;

const POLLIN = 0x0001;
const TIMEOUT_IDLE_MS: i32 = 5000;
const BRIGHTNESS = enum(u8) {
    OFF = 0,
    MED = 1,
    MAX = 2,
};

pub fn main() !void {
    // fn term() void {
    //     running= false;
    // }
    // const IDLE_MSEC: u64 = 5000;
    // var timeout: i32 = @as(i32, @intCast(IDLE_MSEC));

    // // Set up signal handling for SIGTERM
    // const term_action = os.Sigaction{
    //     .handler = os.SIG.IGN,
    //     .mask = {},
    //     .flags = os.SA_RESTART,
    // };
    // try os.sigaction(os.SIGTERM, &term_action, null);

    const blfd = try fs.cwd().openFile("/sys/class/leds/tpacpi::kbd_backlight/brightness", fs.File.OpenFlags{ .mode = fs.File.OpenMode.write_only });
    defer blfd.close();

    const pfd = try fs.cwd().openFile("/dev/input/event0", fs.File.OpenFlags{ .mode = fs.File.OpenMode.read_only });
    defer pfd.close();

    var poll_fd = linux.pollfd{ .fd = pfd.handle, .events = POLLIN, .revents = undefined };
    var poll_fds = [_]linux.pollfd{poll_fd};

    var prev: ?BRIGHTNESS = null;
    var bm: BRIGHTNESS = BRIGHTNESS.MED;
    var buf: [8192]u8 = undefined;
    var rc: u64 = 0;
    var timeout: i32 = -1;
    var exit_requested: bool = false;

    while (!exit_requested) {
        rc = linux.poll(poll_fds[0..], 1, timeout);

        if (rc > 0) {
            std.debug.print("key was pressed", .{});
            _ = try pfd.read(buf[0..]); // Drain all pending events from the input device
            timeout = TIMEOUT_IDLE_MS;
            bm = BRIGHTNESS.MAX;
        } else if (rc == 0) {
            std.debug.print("idling", .{});
            timeout = -1;
            bm = BRIGHTNESS.OFF;
        } else {
            std.debug.print("poll error", .{});
            continue;
        }

        if (bm == prev) {
            continue;
        }

        std.debug.print("writing brightness", .{});
        _ = try blfd.seekTo(13);
        // switch (seek_result) {
        //     @TypeOf(void) => {},
        //     else => {
        //         std.debug.print("Failed to seek: {}\n", .{seek_result});
        //         return null;
        //     },
        // }
        _ = try blfd.write(&[_]u8{@intFromEnum(bm)});
        // switch (write_result) {
        //     usize => {},
        //     else => {
        //         std.debug.print("Failed to write: {}\n", .{write_result});
        //         return null;
        //     },
        // }
        prev = bm;
    }

    std.debug.print("clean up", .{});
    _ = try blfd.seekTo(13);
    _ = try blfd.write(&[1]u8{@intFromEnum(BRIGHTNESS.OFF)});
}
