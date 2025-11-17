const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // This package reads input from the linux evdev interface.
    // Zig packages the linux headers with the types required for reading from this interface.
    // The following translate C calls allows us to convert those types to zig while avoiding
    // needing to link against lib c.
    const input_header = std.fmt.allocPrint(
        b.allocator,
        "{s}{s}",
        .{ b.graph.zig_lib_directory.path.?, "/libc/include/any-linux-any/linux/input.h" },
    ) catch @panic("OOM");

    const libc_any_include = std.fmt.allocPrint(
        b.allocator,
        "{s}{s}",
        .{ b.graph.zig_lib_directory.path.?, "/libc/include/any-linux-any" },
    ) catch @panic("OOM");

    const generic_musl_include = std.fmt.allocPrint(
        b.allocator,
        "{s}{s}",
        .{ b.graph.zig_lib_directory.path.?, "/libc/include/generic-musl" },
    ) catch @panic("OOM");

    const linux_input = b.addTranslateC(.{
        .root_source_file = std.Build.LazyPath{ .cwd_relative = input_header },
        .target = target,
        .optimize = optimize,
        .link_libc = false,
        .use_clang = true,
    });
    linux_input.addIncludePath(std.Build.LazyPath{ .cwd_relative = libc_any_include });
    linux_input.addIncludePath(std.Build.LazyPath{ .cwd_relative = generic_musl_include });

    const joystick = b.addModule("joystick", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    joystick.addImport("linux_input", linux_input.createModule());

    const exe = b.addExecutable(.{
        .name = "joystick",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "joystick", .module = joystick },
            },
        }),
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const tests =
        b.addRunArtifact(b.addTest(.{
            .root_module = joystick,
        }));

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&tests.step);
}
