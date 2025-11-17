const std = @import("std");
const joystick = @import("joystick");

pub fn main() !void {
    // TODO an "open" function that just takes the first found joystick?
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const args = try std.process.argsAlloc(arena.allocator());

    if (args.len < 2) return error.NoJoystickArgumentProvided;
    var joy = try joystick.open(args[1]);

    defer joy.close();
    while (true) {
        try joy.handleEvents();
        std.log.info("joy: {}", .{joy.latest});
        std.Thread.sleep(std.time.ns_per_ms * 10);
    }
}
