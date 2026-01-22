const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Fetch metal-cpp from GitHub
    const metal_cpp_dep = b.dependency("metal_cpp", .{});

    const exe = b.addExecutable(.{
        .name = "gpu-compute",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // Add C header include path for @cImport
    exe.addIncludePath(b.path("src"));

    // Compile our C++ wrapper that uses metal-cpp
    exe.addCSourceFile(.{
        .file = b.path("src/metal_wrapper.cpp"),
        .flags = &.{
            "-std=c++17",
            "-fno-objc-arc",
            "-fno-exceptions",
            "-Wno-deprecated-declarations",
        },
    });

    // Add metal-cpp include path
    exe.addIncludePath(metal_cpp_dep.path(""));

    // Link Apple frameworks
    exe.linkFramework("Metal");
    exe.linkFramework("Foundation");
    exe.linkFramework("QuartzCore");

    // Link C++ standard library
    exe.linkLibCpp();

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the program");
    run_step.dependOn(&run_cmd.step);

    // Tests
    const unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    unit_tests.addIncludePath(b.path("src"));
    unit_tests.addCSourceFile(.{
        .file = b.path("src/metal_wrapper.cpp"),
        .flags = &.{
            "-std=c++17",
            "-fno-objc-arc",
            "-fno-exceptions",
            "-Wno-deprecated-declarations",
        },
    });
    unit_tests.addIncludePath(metal_cpp_dep.path(""));
    unit_tests.linkFramework("Metal");
    unit_tests.linkFramework("Foundation");
    unit_tests.linkFramework("QuartzCore");
    unit_tests.linkLibCpp();

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
