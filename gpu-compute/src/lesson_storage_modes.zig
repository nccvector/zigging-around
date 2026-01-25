const std = @import("std");
const metal = @import("metal.zig");

pub fn main() !void {
    const COUNT: usize = 1024;
    const shader_source: [*:0]const u8 =
        \\#include <metal_stdlib>
        \\using namespace metal;
        \\
        \\kernel void multiply2(
        \\    device float* input[[buffer(0)]],
        \\    uint id [[thread_position_in_grid]]
        \\) {
        \\    input[id] *= 2;
        \\}
    ;

    const device = try metal.Device.create();
    const pipeline = try device.createPipeline(shader_source, "multiply2");

    // Shared buffer
    const shared = try device.createBuffer(f32, COUNT, .{ .storage = .shared });

    // Map to cpu and write data
    const mapped = shared.getHostSlice().?;
    for (0..COUNT) |i| {
        mapped[i] = @floatFromInt(12);
    }

    // Private buffer
    const private = try device.createBuffer(f32, COUNT, .{ .storage = .private });

    var cmd = try device.createCommand();
    {
        // Copy data host -> device
        var blit_enc = cmd.blitEncoder();
        blit_enc.copy(shared, private);
        blit_enc.end();

        var comp_enc = cmd.computeEncoder(pipeline, .{});
        comp_enc.setBuffer(private, 0);
        comp_enc.dispatch1d(COUNT);
        comp_enc.end();

        // Copy data device -> host
        var blit_enc2 = cmd.blitEncoder();
        blit_enc2.copy(private, shared);
        blit_enc2.end();
    }

    device.submit(&cmd);

    for (0..COUNT) |i| {
        try std.testing.expectEqual(@as(f32, 24), mapped[i]);
    }

    std.debug.print("WOW", .{});
}
