const std = @import("std");
const metal = @import("metal.zig");

// =============================================================================
// Lesson 2: Staging Buffers & Double Buffering
// =============================================================================
//
// Goal: Learn how to stream data to the GPU without stalling
//
// The Problem:
//   - If CPU writes to a buffer while GPU is reading it → race condition
//   - If CPU waits for GPU to finish before writing → wasted time (stall)
//
// The Solution: Double (or triple) buffering
//   - Frame N:   GPU processes buffer A, CPU prepares buffer B
//   - Frame N+1: GPU processes buffer B, CPU prepares buffer A
//   - No waiting, maximum throughput!
//
// =============================================================================

const NUM_FRAMES = 10;
const BUFFER_SIZE = 1024;

const shader_source: [*:0]const u8 =
    \\#include <metal_stdlib>
    \\using namespace metal;
    \\
    \\kernel void process(
    \\    device float* data [[buffer(0)]],
    \\    constant uint& frame_number [[buffer(1)]],
    \\    uint id [[thread_position_in_grid]]
    \\) {
    \\    // Multiply by frame number + 1
    \\    data[id] = data[id] * float(frame_number + 1);
    \\}
;

/// Simulates CPU work: preparing data for a frame
fn cpuPrepareData(buffer: []f32, frame: usize) void {
    for (buffer, 0..) |*val, i| {
        // Each frame, we write: value = i + frame
        val.* = @floatFromInt(i + frame);
    }
}

/// Verifies the GPU result for a given frame
fn verifyResult(buffer: []f32, frame: usize) bool {
    for (buffer, 0..) |val, i| {
        // Expected: (i + frame) * (frame + 1)
        const input: f32 = @floatFromInt(i + frame);
        const multiplier: f32 = @floatFromInt(frame + 1);
        const expected = input * multiplier;
        if (@abs(val - expected) > 0.001) {
            std.debug.print("Frame {}: Mismatch at [{}]: expected {}, got {}\n", .{ frame, i, expected, val });
            return false;
        }
    }
    return true;
}

pub fn main() !void {
    const device = try metal.Device.create();
    const pipeline = try device.createPipeline(shader_source, "process");

    std.debug.print("Lesson 2: Double Buffering\n", .{});
    std.debug.print("Device: {s}\n", .{device.name().?});
    std.debug.print("Frames: {}, Buffer size: {}\n\n", .{ NUM_FRAMES, BUFFER_SIZE });

    // -------------------------------------------------------------------------
    // Setup: Create buffers
    // -------------------------------------------------------------------------

    // Two staging buffers for double buffering (shared - CPU accessible)
    var staging = [_]metal.Buffer(f32){
        try device.createBuffer(f32, BUFFER_SIZE, .{ .storage = .shared }),
        try device.createBuffer(f32, BUFFER_SIZE, .{ .storage = .shared }),
    };

    // GPU working buffer (private - fast GPU access)
    const gpu_buffer = try device.createBuffer(f32, BUFFER_SIZE, .{ .storage = .private });

    var fences: [2]?metal.Fence = .{ null, null };
    var last_verified_frame: ?usize = null;

    for (0..NUM_FRAMES) |i| {
        const buf_idx = i % 2;

        // FIRST: Wait for this buffer to be free (GPU might still be using it)
        if (fences[buf_idx]) |f| {
            f.wait();

            // Verify the result from the frame that used this buffer (2 frames ago)
            const completed_frame = i - 2;
            if (verifyResult(staging[buf_idx].getHostSlice().?, completed_frame)) {
                std.debug.print("Frame {}: ✓ verified\n", .{completed_frame});
            } else {
                std.debug.print("Frame {}: ✗ FAILED\n", .{completed_frame});
            }
            last_verified_frame = completed_frame;
        }
        fences[buf_idx] = null;

        // THEN: CPU prepares new data (now safe - GPU is done with this buffer)
        cpuPrepareData(staging[buf_idx].getHostSlice().?, i);
        std.debug.print("Frame {}: CPU prepared data in buffer {}\n", .{ i, buf_idx });

        // GPU work: upload → compute → download
        var cmd = try device.createCommand();
        {
            // Copy data host -> device
            cmd.createBlitEncoder()
                .copy(staging[buf_idx], gpu_buffer)
                .end();

            // Compute
            cmd.createComputeEncoder(pipeline, .{})
                .setBuffer(gpu_buffer, 0)
                .setBytes(@as(u32, @intCast(i)), 1)
                .dispatch1d(BUFFER_SIZE)
                .end();

            // Copy data device -> host
            cmd.createBlitEncoder()
                .copy(gpu_buffer, staging[buf_idx])
                .end();
        }

        fences[buf_idx] = device.submitAsync(&cmd);
        std.debug.print("Frame {}: GPU work submitted\n", .{i});
    }

    // -------------------------------------------------------------------------
    // Drain: Wait for remaining in-flight work and verify
    // -------------------------------------------------------------------------
    std.debug.print("\nDraining remaining frames...\n", .{});

    for (0..2) |buf_idx| {
        if (fences[buf_idx]) |f| {
            f.wait();

            // Calculate which frame used this buffer last
            // Buffer 0: frames 0, 2, 4, 6, 8 → last was 8
            // Buffer 1: frames 1, 3, 5, 7, 9 → last was 9
            const last_frame_for_buffer = NUM_FRAMES - 2 + buf_idx;

            if (last_frame_for_buffer < NUM_FRAMES) {
                if (verifyResult(staging[buf_idx].getHostSlice().?, last_frame_for_buffer)) {
                    std.debug.print("Frame {}: ✓ verified\n", .{last_frame_for_buffer});
                } else {
                    std.debug.print("Frame {}: ✗ FAILED\n", .{last_frame_for_buffer});
                }
            }
        }
    }

    std.debug.print("\nLesson 2 complete!\n", .{});
}
