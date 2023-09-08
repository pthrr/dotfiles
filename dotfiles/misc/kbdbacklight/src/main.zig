const std = @import("std");
const os = std.os;
const fs = std.fs;
const POLLIN = 0x0001;

pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(general_purpose_allocator.deinit() == .ok);
    const gpa = general_purpose_allocator.allocator();
    _ = gpa;

    // var running: bool = true;
    // fn term() void {
    //     running= false;
    // }
    const IDLE_MSEC: u64 = 5000;
    const BRGHT_OFF: u8 = '0';
    const BRGHT_MED: u8 = '1';

    // // Set up signal handling for SIGTERM
    // const term_action = os.Sigaction{
    //     .handler = os.SIG.IGN,
    //     .mask = {},
    //     .flags = os.SA_RESTART,
    // };
    // try os.sigaction(os.SIGTERM, &term_action, null);

    // Open the backlight device file
    // const blfd = try fs.cwd().openFile("/sys/class/leds/tpacpi::kbd_backlight/brightness", fs.File.OpenFlags{ .mode = fs.File.OpenMode.write_only });

    // Open the input device file
    const pfd = try fs.cwd().openFile("/dev/input/event3", fs.File.OpenFlags{ .mode = fs.File.OpenMode.read_only });

    var timeout: i32 = @as(i32, @intCast(IDLE_MSEC));
    var prev: i32 = -1;
    var bm: u8 = BRGHT_MED;
    var dummybuf: [8192]u8 = undefined;
    var poll_fd = os.linux.pollfd{ .fd = pfd.handle, .events = POLLIN, .revents = undefined };
    var rc: u64 = 0;

    while (true) {
        var array = [_]os.linux.pollfd{poll_fd};
        rc = os.linux.poll(array[0..], 1, timeout);

        if (rc > 0) {
            // Drain all pending events from the input device
            _ = try pfd.read(dummybuf[0..]);
            timeout = @as(i32, @intCast(IDLE_MSEC));
            bm = BRGHT_MED;
        } else if (rc == 0) {
            // No events within timeout, turn off backlight
            timeout = -1;
            bm = BRGHT_OFF;
        } else {
            std.debug.print("Poll error", .{}); //: {}\n", .{os.strerror(rc)});
            continue;
        }

        if (bm == prev) {
            continue;
        }

        // Seek and write brightness level
        // try blfd.seekTo(13);
        std.debug.print("writing brightness", .{});
        // try blfd.write(&[1]u8{bm});
        // prev = bm;
    }

    // Clean-up, set brightness to off
    // try blfd.seekTo(13);
    // try blfd.write(&[1]u8{BRGHT_OFF});
}
