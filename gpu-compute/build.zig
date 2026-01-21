const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create metal module from generated bindings
    const metal_module = b.createModule(.{
        .root_source_file = b.path("generated/metal.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "gpu-compute",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "metal", .module = metal_module },
            },
        }),
    });

    // Compile the Objective-C shim
    exe.addCSourceFile(.{
        .file = b.path("generated/metal_shim.m"),
        .flags = &.{ "-fno-objc-arc", "-fobjc-weak", "-Wno-deprecated-declarations" },
    });

    // Link Apple frameworks
    exe.linkFramework("Metal");
    exe.linkFramework("Foundation");

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the program");
    run_step.dependOn(&run_cmd.step);
}
