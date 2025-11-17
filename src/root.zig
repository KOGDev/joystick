// TODO this should be reworked to use the new IO interface maybe?
const std = @import("std");

const c = @import("linux_input");

pub const Joystick = struct {
    lx: f32 = 0.0,
    ly: f32 = 0.0,
    rx: f32 = 0.0,
    ry: f32 = 0.0,
    lt: f32 = 0.0,
    rt: f32 = 0.0,

    dr: bool = false,
    du: bool = false,
    dl: bool = false,
    dd: bool = false,

    br: bool = false, // XBox: B, PS: circle
    bu: bool = false, // XBox: Y, PS: triangle
    bl: bool = false, // XBox: X, PS: square
    bd: bool = false, // XBox: A, PS: x

    lb: bool = false,
    rb: bool = false,

    ls: bool = false,
    rs: bool = false,

    select: bool = false,
    start: bool = false,
    mode: bool = false,
};

fd: std.posix.fd_t,
latest: Joystick,

pub fn open(path: []const u8) std.fs.File.OpenError!@This() {
    return .{ .fd = try std.posix.open(path, .{ .NONBLOCK = true, .ACCMODE = .RDONLY }, 0), .latest = .{} };
}

pub fn close(self: @This()) void {
    std.posix.close(self.fd);
}

pub fn handleEvents(self: *@This()) std.posix.ReadError!void {
    var buf: [16 * @sizeOf(c.input_event)]u8 = undefined;
    while (true) { // TODO cap number of tries?
        const len = std.posix.read(self.fd, &buf) catch |e| switch (e) {
            error.WouldBlock => return,
            else => return e,
        };
        if (len == 0) return;
        if (len % @sizeOf(c.input_event) != 0) @panic("number of read bytes doesn't match the expected size"); // TODO should call read again instead of panic?

        const events: []c.input_event = @ptrCast(@alignCast(buf[0..len]));
        for (events) |event| switch (event.type) {
            c.EV_ABS => switch (event.code) {
                // TODO  read absinfo to get the max values? for now this assumes the typical max values found in the x box style controler
                c.ABS_X => self.latest.lx = @as(f32, @floatFromInt(event.value)) / @as(f32, @floatFromInt(std.math.maxInt(i16))),
                c.ABS_Y => self.latest.ly = -1.0 * @as(f32, @floatFromInt(event.value)) / @as(f32, @floatFromInt(std.math.maxInt(i16))), // y axis are flipped so thumb sticks follow right hand rule
                c.ABS_RX => self.latest.rx = @as(f32, @floatFromInt(event.value)) / @as(f32, @floatFromInt(std.math.maxInt(i16))),
                c.ABS_RY => self.latest.ry = -1.0 * @as(f32, @floatFromInt(event.value)) / @as(f32, @floatFromInt(std.math.maxInt(i16))), // y axis are flipped so thumb sticks follow right hand rule
                c.ABS_Z => self.latest.lt = @as(f32, @floatFromInt(event.value)) / @as(f32, @floatFromInt(std.math.maxInt(u8))),
                c.ABS_RZ => self.latest.rt = @as(f32, @floatFromInt(event.value)) / @as(f32, @floatFromInt(std.math.maxInt(u8))),
                c.ABS_HAT0X => switch (event.value) {
                    1 => {
                        self.latest.dr = true;
                        self.latest.dl = false;
                    },
                    -1 => {
                        self.latest.dr = false;
                        self.latest.dl = true;
                    },
                    else => {
                        self.latest.dr = false;
                        self.latest.dl = false;
                    },
                },
                c.ABS_HAT0Y => switch (event.value) {
                    1 => {
                        self.latest.dd = true;
                        self.latest.du = false;
                    },
                    -1 => {
                        self.latest.dd = false;
                        self.latest.du = true;
                    },
                    else => {
                        self.latest.dd = false;
                        self.latest.du = false;
                    },
                },
                else => {},
            },
            c.EV_KEY => switch (event.code) {
                c.BTN_B => self.latest.br = event.value == 1,
                c.BTN_Y => self.latest.bu = event.value == 1,
                c.BTN_X => self.latest.bl = event.value == 1,
                c.BTN_A => self.latest.bd = event.value == 1,
                c.BTN_TR => self.latest.rb = event.value == 1,
                c.BTN_TL => self.latest.lb = event.value == 1,
                c.BTN_THUMBR => self.latest.rs = event.value == 1,
                c.BTN_THUMBL => self.latest.ls = event.value == 1,
                c.BTN_START => self.latest.start = event.value == 1,
                c.BTN_MODE => self.latest.mode = event.value == 1,
                c.BTN_SELECT => self.latest.select = event.value == 1,
                else => {},
            },
            else => {},
        };
    }
}
