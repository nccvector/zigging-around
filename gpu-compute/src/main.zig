const std = @import("std");
const metal = @import("metal.zig");

pub fn main() !void {
    std.debug.print("Metal Compute - New API Demo\n", .{});
    std.debug.print("============================\n\n", .{});

    const device = try metal.Device.default();

    if (device.name()) |n| {
        std.debug.print("Device: {s}\n", .{n});
    }
    std.debug.print("Unified memory: {}\n", .{device.hasUnifiedMemory()});
    std.debug.print("Ray tracing: {}\n\n", .{device.supportsRaytracing()});

    // Simple vector add demo
    const shader_source: [*:0]const u8 =
        \\#include <metal_stdlib>
        \\using namespace metal;
        \\
        \\kernel void vector_add(
        \\    device const float* A [[buffer(0)]],
        \\    device const float* B [[buffer(1)]],
        \\    device float* C [[buffer(2)]],
        \\    uint id [[thread_position_in_grid]]
        \\) {
        \\    C[id] = A[id] + B[id];
        \\}
    ;

    const pipeline = try device.createPipeline(shader_source, "vector_add");
    const count: usize = 1024;

    var buf_a = try device.buffer(f32, count, .{});
    var buf_b = try device.buffer(f32, count, .{});
    var buf_c = try device.buffer(f32, count, .{});

    // Initialize
    const a = buf_a.contents().?;
    const b = buf_b.contents().?;
    for (0..count) |i| {
        a[i] = @floatFromInt(i);
        b[i] = @floatFromInt(i * 2);
    }

    // Execute using new API
    var cmd = try device.command();
    {
        var enc = cmd.computeEncoder(pipeline, .{});
        defer enc.end();

        enc.buffers(.{ buf_a, buf_b, buf_c });
        enc.dispatch1d(count);
    }
    device.submit(&cmd);

    // Verify
    const c = buf_c.contents().?;
    var correct: usize = 0;
    for (0..count) |i| {
        const expected = a[i] + b[i];
        if (@abs(c[i] - expected) < 0.001) correct += 1;
    }
    std.debug.print("Vector add: {}/{} correct\n", .{ correct, count });
}

// =============================================================================
// Tests - Demonstrating the New API
// =============================================================================

test "basic_compute" {
    const shader_source: [*:0]const u8 =
        \\#include <metal_stdlib>
        \\using namespace metal;
        \\
        \\kernel void fill_42(
        \\    device float* output [[buffer(0)]],
        \\    uint id [[thread_position_in_grid]]
        \\) {
        \\    output[id] = 42.0;
        \\}
    ;

    const count: usize = 16_000_000;

    const device = try metal.Device.default();
    const pipeline = try device.createPipeline(shader_source, "fill_42");
    const buf = try device.buffer(f32, count, .{});

    // New API: scope-based encoder
    var cmd = try device.command();
    {
        var enc = cmd.computeEncoder(pipeline, .{});
        defer enc.end();

        enc.buffer(buf, 0);
        enc.dispatch1d(count);
    }
    device.submit(&cmd);

    // Verify
    const output = buf.contents().?;
    for (output) |val| {
        try std.testing.expectEqual(@as(f32, 42.0), val);
    }
}

test "async_submission" {
    const shader_source: [*:0]const u8 =
        \\#include <metal_stdlib>
        \\using namespace metal;
        \\
        \\kernel void fill_42(
        \\    device float* output [[buffer(0)]],
        \\    uint id [[thread_position_in_grid]]
        \\) {
        \\    output[id] = 42.0;
        \\}
    ;

    const count: usize = 16_000_000;

    const device = try metal.Device.default();
    const pipeline = try device.createPipeline(shader_source, "fill_42");
    const buf = try device.buffer(f32, count, .{});

    var cmd = try device.command();
    {
        var enc = cmd.computeEncoder(pipeline, .{});
        defer enc.end();

        enc.buffer(buf, 0);
        enc.dispatch1d(count);
    }

    // Async submission
    const fence = device.submitAsync(&cmd);

    // Could do CPU work here...

    fence.wait();

    // Verify
    const output = buf.contents().?;
    for (output) |val| {
        try std.testing.expectEqual(@as(f32, 42.0), val);
    }
}

test "pipeline_switching" {
    const shader_source: [*:0]const u8 =
        \\#include <metal_stdlib>
        \\using namespace metal;
        \\
        \\kernel void double_it(
        \\    device float* data [[buffer(0)]],
        \\    uint id [[thread_position_in_grid]]
        \\) {
        \\    data[id] = data[id] * 2.0;
        \\}
        \\
        \\kernel void add_ten(
        \\    device float* data [[buffer(0)]],
        \\    uint id [[thread_position_in_grid]]
        \\) {
        \\    data[id] = data[id] + 10.0;
        \\}
    ;

    const count: usize = 1024;

    const device = try metal.Device.default();
    const double_pipeline = try device.createPipeline(shader_source, "double_it");
    const add_pipeline = try device.createPipeline(shader_source, "add_ten");
    var buf = try device.buffer(f32, count, .{});

    // Initialize with 1.0
    const data = buf.contents().?;
    for (data) |*val| val.* = 1.0;

    // Single encoder, switch pipelines (cheap!)
    // 1.0 -> double -> 2.0 -> add_ten -> 12.0
    var cmd = try device.command();
    {
        var enc = cmd.computeEncoder(double_pipeline, .{});
        defer enc.end();

        enc.buffer(buf, 0);
        enc.dispatch1d(count);

        // Switch pipeline (same encoder, cheap!)
        enc.pipeline(add_pipeline);
        enc.buffer(buf, 0);
        enc.dispatch1d(count);
    }
    device.submit(&cmd);

    // Verify
    for (data) |val| {
        try std.testing.expectEqual(@as(f32, 12.0), val);
    }
}

test "multi_encoder_command_buffer" {
    const shader_source: [*:0]const u8 =
        \\#include <metal_stdlib>
        \\using namespace metal;
        \\
        \\kernel void fill_42(
        \\    device float* data [[buffer(0)]],
        \\    uint id [[thread_position_in_grid]]
        \\) {
        \\    data[id] = 42.0;
        \\}
    ;

    const count: usize = 1024;

    const device = try metal.Device.default();
    const pipeline = try device.createPipeline(shader_source, "fill_42");
    const src_buf = try device.buffer(f32, count, .{});
    const dst_buf = try device.buffer(f32, count, .{});

    var cmd = try device.command();

    // Compute pass: fill src with 42
    {
        var enc = cmd.computeEncoder(pipeline, .{});
        defer enc.end();

        enc.buffer(src_buf, 0);
        enc.dispatch1d(count);
    }

    // Blit pass: copy src to dst
    {
        var enc = cmd.blitEncoder();
        defer enc.end();

        enc.copy(src_buf, dst_buf);
    }

    device.submit(&cmd);

    // Verify dst has 42.0
    const output = dst_buf.contents().?;
    for (output) |val| {
        try std.testing.expectEqual(@as(f32, 42.0), val);
    }
}

test "bytes_uniform_data" {
    const shader_source: [*:0]const u8 =
        \\#include <metal_stdlib>
        \\using namespace metal;
        \\
        \\struct Params {
        \\    float scale;
        \\    uint offset;
        \\};
        \\
        \\kernel void scale_kernel(
        \\    device float* data [[buffer(0)]],
        \\    constant Params& params [[buffer(1)]],
        \\    uint tid [[thread_position_in_grid]]
        \\) {
        \\    data[tid + params.offset] *= params.scale;
        \\}
    ;

    const Params = extern struct {
        scale: f32,
        offset: u32,
    };

    const device = try metal.Device.default();
    const pipeline = try device.createPipeline(shader_source, "scale_kernel");
    var buf = try device.buffer(f32, 8, .{});

    // Initialize
    const data = buf.contents().?;
    for (data, 0..) |*v, i| v.* = @floatFromInt(i + 1);

    var cmd = try device.command();
    {
        var enc = cmd.computeEncoder(pipeline, .{});
        defer enc.end();

        enc.buffer(buf, 0);
        enc.bytes(Params{ .scale = 2.0, .offset = 0 }, 1);
        enc.dispatch1d(8);
    }
    device.submit(&cmd);

    // Verify: [2, 4, 6, 8, 10, 12, 14, 16]
    for (data, 0..) |val, i| {
        try std.testing.expectEqual(@as(f32, @floatFromInt((i + 1) * 2)), val);
    }
}

test "storage_modes" {
    const device = try metal.Device.default();

    // Shared - CPU accessible
    const shared_buf = try device.buffer(f32, 4, .{ .storage = .shared });
    try std.testing.expect(shared_buf.contents() != null);

    // Private - GPU only
    const private_buf = try device.buffer(f32, 4, .{ .storage = .private });
    try std.testing.expect(private_buf.contents() == null);

    // Convenience methods
    const shared2 = try device.bufferShared(f32, 4);
    try std.testing.expect(shared2.contents() != null);

    const private2 = try device.bufferPrivate(f32, 4);
    try std.testing.expect(private2.contents() == null);
}

test "concurrent_dispatch_with_barrier" {
    const shader_source: [*:0]const u8 =
        \\#include <metal_stdlib>
        \\using namespace metal;
        \\
        \\struct Params {
        \\    float scale;
        \\    uint offset;
        \\};
        \\
        \\kernel void scale_kernel(
        \\    device float* data [[buffer(0)]],
        \\    constant Params& params [[buffer(1)]],
        \\    uint tid [[thread_position_in_grid]]
        \\) {
        \\    data[tid + params.offset] *= params.scale;
        \\}
    ;

    const Params = extern struct {
        scale: f32,
        offset: u32,
    };

    const device = try metal.Device.default();
    const pipeline = try device.createPipeline(shader_source, "scale_kernel");
    var buf = try device.buffer(f32, 8, .{});

    const data = buf.contents().?;
    for (data, 0..) |*v, i| v.* = @floatFromInt(i + 1);

    var cmd = try device.command();
    {
        // Concurrent dispatch mode
        var enc = cmd.computeEncoder(pipeline, .{ .concurrent = true });
        defer enc.end();

        // x2
        enc.buffer(buf, 0);
        enc.bytes(Params{ .scale = 2.0, .offset = 0 }, 1);
        enc.dispatch1d(8);

        // Barrier required for concurrent when same buffer
        enc.barrier(.buffers);

        // x3
        enc.bytes(Params{ .scale = 3.0, .offset = 0 }, 1);
        enc.dispatch1d(8);
    }
    device.submit(&cmd);

    // Verify: [6, 12, 18, 24, 30, 36, 42, 48]
    for (data, 0..) |val, i| {
        try std.testing.expectEqual(@as(f32, @floatFromInt((i + 1) * 6)), val);
    }
}

test "acceleration_structure" {
    const device = try metal.Device.default();

    if (!device.supportsRaytracing()) {
        return; // Skip on devices without ray tracing
    }

    // Create vertex buffer for a triangle
    const vertices = [_]f32{
        0.0, 0.0, 0.0, // v0
        1.0, 0.0, 0.0, // v1
        0.5, 1.0, 0.0, // v2
    };

    var vertex_buf = try device.buffer(f32, vertices.len, .{});
    @memcpy(vertex_buf.contents().?, &vertices);

    // Create index buffer
    const indices = [_]u32{ 0, 1, 2 };
    var index_buf = try device.buffer(u32, indices.len, .{});
    @memcpy(index_buf.contents().?, &indices);

    // Triangle geometry descriptor (fluent API)
    const triangle_geo = metal.TriangleGeometryDescriptor.init()
        .vertexBuffer(vertex_buf, 12)
        .indexBuffer(index_buf, .uint32)
        .triangleCount(1);

    // BLAS descriptor
    var blas_desc = metal.PrimitiveAccelerationStructureDescriptor.init();
    blas_desc.addGeometry(triangle_geo);
    blas_desc.build();

    // Get sizes and allocate
    const sizes = device.accelSizes(blas_desc);
    try std.testing.expect(sizes.acceleration_structure_size > 0);

    const blas = try device.accelerationStructure(sizes.acceleration_structure_size);
    const scratch = try device.buffer(u8, sizes.build_scratch_buffer_size, .{});

    // Build using accel encoder
    var cmd = try device.command();
    {
        var enc = cmd.accelEncoder();
        defer enc.end();

        enc.build(blas, blas_desc, scratch);
    }
    device.submit(&cmd);

    try std.testing.expect(blas.size() > 0);
}

test "texture_2d" {
    const shader_source: [*:0]const u8 =
        \\#include <metal_stdlib>
        \\using namespace metal;
        \\
        \\kernel void invert(
        \\    texture2d<float, access::read> input [[texture(0)]],
        \\    texture2d<float, access::write> output [[texture(1)]],
        \\    uint2 gid [[thread_position_in_grid]]
        \\) {
        \\    if (gid.x >= input.get_width() || gid.y >= input.get_height()) return;
        \\    float4 color = input.read(gid);
        \\    output.write(float4(1.0 - color.rgb, color.a), gid);
        \\}
    ;

    const device = try metal.Device.default();
    const pipeline = try device.createPipeline(shader_source, "invert");

    const width: u32 = 64;
    const height: u32 = 64;

    const input_tex = try device.texture2d(width, height, .rgba8unorm, .{ .read = true });
    const output_tex = try device.texture2d(width, height, .rgba8unorm, .{ .write = true });

    // Create test pattern (white)
    var pixels: [width * height * 4]u8 = undefined;
    for (0..width * height) |i| {
        pixels[i * 4 + 0] = 255; // R
        pixels[i * 4 + 1] = 255; // G
        pixels[i * 4 + 2] = 255; // B
        pixels[i * 4 + 3] = 255; // A
    }
    input_tex.upload(&pixels);

    var cmd = try device.command();
    {
        var enc = cmd.computeEncoder(pipeline, .{});
        defer enc.end();

        enc.textures(.{ input_tex, output_tex });
        enc.dispatch2d(width, height);
    }
    device.submit(&cmd);

    // Verify inversion (white -> black)
    var result: [width * height * 4]u8 = undefined;
    output_tex.download(&result);

    // Check first pixel is black (inverted from white)
    try std.testing.expectEqual(@as(u8, 0), result[0]); // R
    try std.testing.expectEqual(@as(u8, 0), result[1]); // G
    try std.testing.expectEqual(@as(u8, 0), result[2]); // B
    try std.testing.expectEqual(@as(u8, 255), result[3]); // A preserved
}

test "buffers_convenience" {
    const shader_source: [*:0]const u8 =
        \\#include <metal_stdlib>
        \\using namespace metal;
        \\
        \\kernel void vector_add(
        \\    device const float* A [[buffer(0)]],
        \\    device const float* B [[buffer(1)]],
        \\    device float* C [[buffer(2)]],
        \\    uint id [[thread_position_in_grid]]
        \\) {
        \\    C[id] = A[id] + B[id];
        \\}
    ;

    const count: usize = 1024;

    const device = try metal.Device.default();
    const pipeline = try device.createPipeline(shader_source, "vector_add");

    var buf_a = try device.buffer(f32, count, .{});
    var buf_b = try device.buffer(f32, count, .{});
    var buf_c = try device.buffer(f32, count, .{});

    const a = buf_a.contents().?;
    const b = buf_b.contents().?;
    for (0..count) |i| {
        a[i] = @floatFromInt(i);
        b[i] = @floatFromInt(i * 2);
    }

    var cmd = try device.command();
    {
        var enc = cmd.computeEncoder(pipeline, .{});
        defer enc.end();

        // Convenience: bind multiple buffers at once
        enc.buffers(.{ buf_a, buf_b, buf_c });
        enc.dispatch1d(count);
    }
    device.submit(&cmd);

    const c = buf_c.contents().?;
    for (0..count) |i| {
        const expected = a[i] + b[i];
        try std.testing.expectApproxEqAbs(expected, c[i], 0.001);
    }
}
