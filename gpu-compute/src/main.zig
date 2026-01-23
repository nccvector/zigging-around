const std = @import("std");
const mtl = @cImport({
    @cInclude("metal_wrapper.h");
});
const zmtl = @import("metal.zig");

pub fn main() !void {

    // Metal shader source - compiled at runtime
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
        \\
        \\kernel void vector_multiply(
        \\    device const float* A [[buffer(0)]],
        \\    device const float* B [[buffer(1)]],
        \\    device float* C [[buffer(2)]],
        \\    uint id [[thread_position_in_grid]]
        \\) {
        \\    C[id] = A[id] * B[id];
        \\}
        \\
        \\kernel void vector_fma(
        \\    device const float* A [[buffer(0)]],
        \\    device const float* B [[buffer(1)]],
        \\    device const float* C [[buffer(2)]],
        \\    device float* D [[buffer(3)]],
        \\    uint id [[thread_position_in_grid]]
        \\) {
        \\    D[id] = fma(A[id], B[id], C[id]);
        \\}
    ;

    const ARRAY_SIZE: usize = 16 * 1024 * 1024; // 16M elements
    const WARMUP_ITERS: usize = 3;
    const BENCH_ITERS: usize = 10;

    // Get Metal device
    const device = mtl.MTLWrapperCreateSystemDefaultDevice() orelse {
        std.debug.print("Metal not available\n", .{});
        return;
    };

    std.debug.print("Metal GPU Compute Benchmark (metal-cpp)\n", .{});
    std.debug.print("========================================\n\n", .{});

    // Print device info
    if (mtl.MTLDeviceName(device)) |name| {
        std.debug.print("Device: {s}\n", .{name});
    }
    std.debug.print("Unified memory: {}\n", .{mtl.MTLDeviceHasUnifiedMemory(device)});

    // Compile shader from source
    var compile_error: mtl.NSErrorRef = null;
    const library = mtl.MTLDeviceNewLibraryWithSource(
        device,
        shader_source,
        null,
        &compile_error,
    ) orelse {
        if (mtl.NSErrorLocalizedDescription(compile_error)) |desc| {
            std.debug.print("Failed to compile shader: {s}\n", .{desc});
        } else {
            std.debug.print("Failed to compile shader (unknown error)\n", .{});
        }
        return;
    };

    // Get kernel functions
    const add_fn = mtl.MTLLibraryNewFunctionWithName(library, "vector_add") orelse {
        std.debug.print("Failed to get vector_add function\n", .{});
        return;
    };
    const mul_fn = mtl.MTLLibraryNewFunctionWithName(library, "vector_multiply") orelse {
        std.debug.print("Failed to get vector_multiply function\n", .{});
        return;
    };
    const fma_fn = mtl.MTLLibraryNewFunctionWithName(library, "vector_fma") orelse {
        std.debug.print("Failed to get vector_fma function\n", .{});
        return;
    };

    // Create compute pipelines
    var pipeline_error: mtl.NSErrorRef = null;
    const add_pipeline = mtl.MTLDeviceNewComputePipelineStateWithFunction(device, add_fn, &pipeline_error) orelse {
        std.debug.print("Failed to create add pipeline\n", .{});
        return;
    };
    const mul_pipeline = mtl.MTLDeviceNewComputePipelineStateWithFunction(device, mul_fn, &pipeline_error) orelse {
        std.debug.print("Failed to create mul pipeline\n", .{});
        return;
    };
    const fma_pipeline = mtl.MTLDeviceNewComputePipelineStateWithFunction(device, fma_fn, &pipeline_error) orelse {
        std.debug.print("Failed to create fma pipeline\n", .{});
        return;
    };

    const max_threads = mtl.MTLComputePipelineStateMaxTotalThreadsPerThreadgroup(add_pipeline);
    std.debug.print("Array size: {} elements ({} MB)\n", .{ ARRAY_SIZE, (ARRAY_SIZE * @sizeOf(f32)) / (1024 * 1024) });
    std.debug.print("Max threads/threadgroup: {}\n\n", .{max_threads});

    // Create buffers (using shared storage mode = 0)
    const buffer_size = ARRAY_SIZE * @sizeOf(f32);
    const storage_mode: u64 = 0; // MTLResourceStorageModeShared

    const buffer_a = mtl.MTLDeviceNewBufferWithLength(device, buffer_size, storage_mode) orelse {
        std.debug.print("Failed to create buffer A\n", .{});
        return;
    };
    const buffer_b = mtl.MTLDeviceNewBufferWithLength(device, buffer_size, storage_mode) orelse {
        std.debug.print("Failed to create buffer B\n", .{});
        return;
    };
    const buffer_c = mtl.MTLDeviceNewBufferWithLength(device, buffer_size, storage_mode) orelse {
        std.debug.print("Failed to create buffer C\n", .{});
        return;
    };
    const buffer_d = mtl.MTLDeviceNewBufferWithLength(device, buffer_size, storage_mode) orelse {
        std.debug.print("Failed to create buffer D\n", .{});
        return;
    };

    // Get pointers and initialize
    const ptr_a: [*]f32 = @ptrCast(@alignCast(mtl.MTLBufferContents(buffer_a)));
    const ptr_b: [*]f32 = @ptrCast(@alignCast(mtl.MTLBufferContents(buffer_b)));
    const ptr_c: [*]f32 = @ptrCast(@alignCast(mtl.MTLBufferContents(buffer_c)));
    const ptr_d: [*]f32 = @ptrCast(@alignCast(mtl.MTLBufferContents(buffer_d)));

    for (0..ARRAY_SIZE) |i| {
        ptr_a[i] = @floatFromInt(i % 1000);
        ptr_b[i] = @floatFromInt((i * 7) % 1000);
        ptr_c[i] = @floatFromInt((i * 13) % 1000);
        ptr_d[i] = 0;
    }

    const queue = mtl.MTLDeviceNewCommandQueue(device) orelse {
        std.debug.print("Failed to create command queue\n", .{});
        return;
    };

    // Calculate dispatch sizes
    const threadgroup_size = @min(max_threads, 1024);
    const grid_size = (ARRAY_SIZE + threadgroup_size - 1) / threadgroup_size;

    const threadgroups = mtl.MTLSize{ .width = grid_size, .height = 1, .depth = 1 };
    const threads_per_group = mtl.MTLSize{ .width = threadgroup_size, .height = 1, .depth = 1 };

    // =========================================================================
    // Benchmark: Vector Add
    // =========================================================================
    std.debug.print("Vector Add (C = A + B):\n", .{});

    // GPU warmup
    for (0..WARMUP_ITERS) |_| {
        const cmd = mtl.MTLCommandQueueCommandBuffer(queue) orelse return;
        const enc = mtl.MTLCommandBufferComputeCommandEncoder(cmd) orelse return;
        mtl.MTLComputeCommandEncoderSetComputePipelineState(enc, add_pipeline);
        mtl.MTLComputeCommandEncoderSetBuffer(enc, buffer_a, 0, 0);
        mtl.MTLComputeCommandEncoderSetBuffer(enc, buffer_b, 0, 1);
        mtl.MTLComputeCommandEncoderSetBuffer(enc, buffer_c, 0, 2);
        mtl.MTLComputeCommandEncoderDispatchThreadgroups(enc, threadgroups, threads_per_group);
        mtl.MTLComputeCommandEncoderEndEncoding(enc);
        mtl.MTLCommandBufferCommit(cmd);
        mtl.MTLCommandBufferWaitUntilCompleted(cmd);
    }

    // GPU benchmark
    var gpu_total: u64 = 0;
    for (0..BENCH_ITERS) |_| {
        var timer = try std.time.Timer.start();
        const cmd = mtl.MTLCommandQueueCommandBuffer(queue) orelse return;
        const enc = mtl.MTLCommandBufferComputeCommandEncoder(cmd) orelse return;
        mtl.MTLComputeCommandEncoderSetComputePipelineState(enc, add_pipeline);
        mtl.MTLComputeCommandEncoderSetBuffer(enc, buffer_a, 0, 0);
        mtl.MTLComputeCommandEncoderSetBuffer(enc, buffer_b, 0, 1);
        mtl.MTLComputeCommandEncoderSetBuffer(enc, buffer_c, 0, 2);
        mtl.MTLComputeCommandEncoderDispatchThreadgroups(enc, threadgroups, threads_per_group);
        mtl.MTLComputeCommandEncoderEndEncoding(enc);
        mtl.MTLCommandBufferCommit(cmd);
        mtl.MTLCommandBufferWaitUntilCompleted(cmd);
        gpu_total += timer.read();
    }
    const gpu_avg = gpu_total / BENCH_ITERS;

    // CPU benchmark
    var cpu_total: u64 = 0;
    for (0..BENCH_ITERS) |_| {
        var timer = try std.time.Timer.start();
        for (0..ARRAY_SIZE) |i| {
            ptr_c[i] = ptr_a[i] + ptr_b[i];
        }
        cpu_total += timer.read();
    }
    const cpu_avg = cpu_total / BENCH_ITERS;

    const gpu_ms = @as(f64, @floatFromInt(gpu_avg)) / 1_000_000.0;
    const cpu_ms = @as(f64, @floatFromInt(cpu_avg)) / 1_000_000.0;
    const speedup = cpu_ms / gpu_ms;
    const gpu_throughput = @as(f64, @floatFromInt(ARRAY_SIZE * @sizeOf(f32) * 3)) / (gpu_ms / 1000.0) / 1e9;

    std.debug.print("  GPU: {d:.3} ms  ({d:.1} GB/s)\n", .{ gpu_ms, gpu_throughput });
    std.debug.print("  CPU: {d:.3} ms\n", .{cpu_ms});
    std.debug.print("  Speedup: {d:.2}x\n\n", .{speedup});

    // Verify
    var correct: usize = 0;
    for (0..100) |i| {
        if (@abs(ptr_c[i] - (ptr_a[i] + ptr_b[i])) < 0.001) correct += 1;
    }
    std.debug.print("  Verification: {}/100 correct\n\n", .{correct});

    // =========================================================================
    // Benchmark: Vector Multiply
    // =========================================================================
    std.debug.print("Vector Multiply (C = A * B):\n", .{});

    for (0..WARMUP_ITERS) |_| {
        const cmd = mtl.MTLCommandQueueCommandBuffer(queue) orelse return;
        const enc = mtl.MTLCommandBufferComputeCommandEncoder(cmd) orelse return;
        mtl.MTLComputeCommandEncoderSetComputePipelineState(enc, mul_pipeline);
        mtl.MTLComputeCommandEncoderSetBuffer(enc, buffer_a, 0, 0);
        mtl.MTLComputeCommandEncoderSetBuffer(enc, buffer_b, 0, 1);
        mtl.MTLComputeCommandEncoderSetBuffer(enc, buffer_c, 0, 2);
        mtl.MTLComputeCommandEncoderDispatchThreadgroups(enc, threadgroups, threads_per_group);
        mtl.MTLComputeCommandEncoderEndEncoding(enc);
        mtl.MTLCommandBufferCommit(cmd);
        mtl.MTLCommandBufferWaitUntilCompleted(cmd);
    }

    gpu_total = 0;
    for (0..BENCH_ITERS) |_| {
        var timer = try std.time.Timer.start();
        const cmd = mtl.MTLCommandQueueCommandBuffer(queue) orelse return;
        const enc = mtl.MTLCommandBufferComputeCommandEncoder(cmd) orelse return;
        mtl.MTLComputeCommandEncoderSetComputePipelineState(enc, mul_pipeline);
        mtl.MTLComputeCommandEncoderSetBuffer(enc, buffer_a, 0, 0);
        mtl.MTLComputeCommandEncoderSetBuffer(enc, buffer_b, 0, 1);
        mtl.MTLComputeCommandEncoderSetBuffer(enc, buffer_c, 0, 2);
        mtl.MTLComputeCommandEncoderDispatchThreadgroups(enc, threadgroups, threads_per_group);
        mtl.MTLComputeCommandEncoderEndEncoding(enc);
        mtl.MTLCommandBufferCommit(cmd);
        mtl.MTLCommandBufferWaitUntilCompleted(cmd);
        gpu_total += timer.read();
    }
    const gpu_mul_avg = gpu_total / BENCH_ITERS;

    cpu_total = 0;
    for (0..BENCH_ITERS) |_| {
        var timer = try std.time.Timer.start();
        for (0..ARRAY_SIZE) |i| {
            ptr_c[i] = ptr_a[i] * ptr_b[i];
        }
        cpu_total += timer.read();
    }
    const cpu_mul_avg = cpu_total / BENCH_ITERS;

    const gpu_mul_ms = @as(f64, @floatFromInt(gpu_mul_avg)) / 1_000_000.0;
    const cpu_mul_ms = @as(f64, @floatFromInt(cpu_mul_avg)) / 1_000_000.0;
    const mul_speedup = cpu_mul_ms / gpu_mul_ms;
    const mul_throughput = @as(f64, @floatFromInt(ARRAY_SIZE * @sizeOf(f32) * 3)) / (gpu_mul_ms / 1000.0) / 1e9;

    std.debug.print("  GPU: {d:.3} ms  ({d:.1} GB/s)\n", .{ gpu_mul_ms, mul_throughput });
    std.debug.print("  CPU: {d:.3} ms\n", .{cpu_mul_ms});
    std.debug.print("  Speedup: {d:.2}x\n\n", .{mul_speedup});

    // =========================================================================
    // Benchmark: FMA
    // =========================================================================
    std.debug.print("Fused Multiply-Add (D = A * B + C):\n", .{});

    for (0..WARMUP_ITERS) |_| {
        const cmd = mtl.MTLCommandQueueCommandBuffer(queue) orelse return;
        const enc = mtl.MTLCommandBufferComputeCommandEncoder(cmd) orelse return;
        mtl.MTLComputeCommandEncoderSetComputePipelineState(enc, fma_pipeline);
        mtl.MTLComputeCommandEncoderSetBuffer(enc, buffer_a, 0, 0);
        mtl.MTLComputeCommandEncoderSetBuffer(enc, buffer_b, 0, 1);
        mtl.MTLComputeCommandEncoderSetBuffer(enc, buffer_c, 0, 2);
        mtl.MTLComputeCommandEncoderSetBuffer(enc, buffer_d, 0, 3);
        mtl.MTLComputeCommandEncoderDispatchThreadgroups(enc, threadgroups, threads_per_group);
        mtl.MTLComputeCommandEncoderEndEncoding(enc);
        mtl.MTLCommandBufferCommit(cmd);
        mtl.MTLCommandBufferWaitUntilCompleted(cmd);
    }

    gpu_total = 0;
    for (0..BENCH_ITERS) |_| {
        var timer = try std.time.Timer.start();
        const cmd = mtl.MTLCommandQueueCommandBuffer(queue) orelse return;
        const enc = mtl.MTLCommandBufferComputeCommandEncoder(cmd) orelse return;
        mtl.MTLComputeCommandEncoderSetComputePipelineState(enc, fma_pipeline);
        mtl.MTLComputeCommandEncoderSetBuffer(enc, buffer_a, 0, 0);
        mtl.MTLComputeCommandEncoderSetBuffer(enc, buffer_b, 0, 1);
        mtl.MTLComputeCommandEncoderSetBuffer(enc, buffer_c, 0, 2);
        mtl.MTLComputeCommandEncoderSetBuffer(enc, buffer_d, 0, 3);
        mtl.MTLComputeCommandEncoderDispatchThreadgroups(enc, threadgroups, threads_per_group);
        mtl.MTLComputeCommandEncoderEndEncoding(enc);
        mtl.MTLCommandBufferCommit(cmd);
        mtl.MTLCommandBufferWaitUntilCompleted(cmd);
        gpu_total += timer.read();
    }
    const gpu_fma_avg = gpu_total / BENCH_ITERS;

    cpu_total = 0;
    for (0..BENCH_ITERS) |_| {
        var timer = try std.time.Timer.start();
        for (0..ARRAY_SIZE) |i| {
            ptr_d[i] = @mulAdd(f32, ptr_a[i], ptr_b[i], ptr_c[i]);
        }
        cpu_total += timer.read();
    }
    const cpu_fma_avg = cpu_total / BENCH_ITERS;

    const gpu_fma_ms = @as(f64, @floatFromInt(gpu_fma_avg)) / 1_000_000.0;
    const cpu_fma_ms = @as(f64, @floatFromInt(cpu_fma_avg)) / 1_000_000.0;
    const fma_speedup = cpu_fma_ms / gpu_fma_ms;
    const fma_throughput = @as(f64, @floatFromInt(ARRAY_SIZE * @sizeOf(f32) * 4)) / (gpu_fma_ms / 1000.0) / 1e9;

    std.debug.print("  GPU: {d:.3} ms  ({d:.1} GB/s)\n", .{ gpu_fma_ms, fma_throughput });
    std.debug.print("  CPU: {d:.3} ms\n", .{cpu_fma_ms});
    std.debug.print("  Speedup: {d:.2}x\n\n", .{fma_speedup});

    // Verify FMA
    correct = 0;
    for (0..100) |i| {
        const expected = @mulAdd(f32, ptr_a[i], ptr_b[i], ptr_c[i]);
        if (@abs(ptr_d[i] - expected) < 0.001) correct += 1;
    }
    std.debug.print("  Verification: {}/100 correct\n", .{correct});
}

test "lesson_01_hello_compute" {
    // Shader: every thread writes 42.0 to its position
    const shader_source: [*:0]const u8 =
        \\#include <metal_stdlib>
        \\using namespace metal;
        \\
        \\kernel void hello(
        \\    device float* output [[buffer(0)]],
        \\    uint id [[thread_position_in_grid]]
        \\) {
        \\    output[id] = 42.0;
        \\}
    ;

    const array_len: usize = 16_000_000;

    // Setup
    var device = try zmtl.Device.default();
    const pipeline = try device.createComputePipeline(shader_source, "hello");
    const buffer = try device.createBuffer(f32, array_len);

    // Submit command - device manages queue internally
    device.submit(
        zmtl.cmd
            .compute(pipeline)
            .setBuffer(buffer, 0, .{})
            .dispatch1d(pipeline, array_len),
    );

    // Verify
    const output = buffer.contents().?;
    for (output) |val| {
        try std.testing.expectEqual(@as(f32, 42.0), val);
    }
}

test "lesson_01_async" {
    const shader_source: [*:0]const u8 =
        \\#include <metal_stdlib>
        \\using namespace metal;
        \\
        \\kernel void hello(
        \\    device float* output [[buffer(0)]],
        \\    uint id [[thread_position_in_grid]]
        \\) {
        \\    output[id] = 42.0;
        \\}
    ;

    const array_len: usize = 16_000_000;

    var device = try zmtl.Device.default();
    const pipeline = try device.createComputePipeline(shader_source, "hello");
    const buffer = try device.createBuffer(f32, array_len);

    // Async submission
    const fence = device.submitAsync(
        zmtl.cmd
            .compute(pipeline)
            .setBuffer(buffer, 0, .{})
            .dispatch1d(pipeline, array_len),
    );

    // Could do other work here...

    // Wait for completion
    fence.wait();

    // Verify
    const output = buffer.contents().?;
    for (output) |val| {
        try std.testing.expectEqual(@as(f32, 42.0), val);
    }
}

test "lesson_02_pipeline_switch" {
    // Two kernels: one doubles, one adds 10
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

    const array_len: usize = 1024;

    var device = try zmtl.Device.default();
    const double_pipeline = try device.createComputePipeline(shader_source, "double_it");
    const add_pipeline = try device.createComputePipeline(shader_source, "add_ten");
    const buffer = try device.createBuffer(f32, array_len);

    // Initialize buffer with 1.0
    const data = buffer.contents().?;
    for (data) |*val| {
        val.* = 1.0;
    }

    // Single command, switching pipelines
    // 1.0 -> double -> 2.0 -> add_ten -> 12.0
    device.submit(
        zmtl.cmd
            .compute(double_pipeline)
            .setBuffer(buffer, 0, .{})
            .dispatch1d(double_pipeline, array_len)
            .compute(add_pipeline) // switch pipeline, same encoder!
            .setBuffer(buffer, 0, .{})
            .dispatch1d(add_pipeline, array_len),
    );

    // Verify: should be 12.0
    const output = buffer.contents().?;
    for (output) |val| {
        try std.testing.expectEqual(@as(f32, 12.0), val);
    }
}

test "lesson_03_compute_and_blit" {
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

    const array_len: usize = 1024;

    var device = try zmtl.Device.default();
    const pipeline = try device.createComputePipeline(shader_source, "fill_42");
    const src_buffer = try device.createBuffer(f32, array_len);
    const dst_buffer = try device.createBuffer(f32, array_len);

    // Compute fills src, then blit copies to dst
    device.submit(
        zmtl.cmd
            .compute(pipeline)
            .setBuffer(src_buffer, 0, .{})
            .dispatch1d(pipeline, array_len)
            .blit() // switch to blit encoder
            .copy(src_buffer, dst_buffer, src_buffer.byteSize(), .{}),
    );

    // Verify dst has 42.0
    const output = dst_buffer.contents().?;
    for (output) |val| {
        try std.testing.expectEqual(@as(f32, 42.0), val);
    }
}

test "lesson_04_setBytes" {
    // Test setBytes for inline uniform data
    const scale_shader: [*:0]const u8 =
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

    var device = try zmtl.Device.default();
    const pipeline = try device.createComputePipeline(scale_shader, "scale_kernel");
    var buffer = try device.createBuffer(f32, 8);

    // Initialize with 1..8
    const data = buffer.contents().?;
    for (data, 0..) |*v, i| v.* = @floatFromInt(i + 1);

    // Scale by 2.0 using setBytes
    device.submit(
        zmtl.cmd
            .compute(pipeline)
            .setBuffer(buffer, 0, .{})
            .setBytes(&Params{ .scale = 2.0, .offset = 0 }, 1)
            .dispatch1d(pipeline, 8),
    );

    // Verify: should be [2, 4, 6, 8, 10, 12, 14, 16]
    for (data, 0..) |val, i| {
        try std.testing.expectEqual(@as(f32, @floatFromInt((i + 1) * 2)), val);
    }
}

test "lesson_05_storage_modes" {
    var device = try zmtl.Device.default();

    // Shared buffer - CPU accessible
    const shared_buf = try device.createBufferWithMode(f32, 4, .shared);
    try std.testing.expect(shared_buf.contents() != null);

    // Private buffer - GPU only, not CPU accessible
    const private_buf = try device.createBufferWithMode(f32, 4, .private);
    try std.testing.expect(private_buf.contents() == null);
}

test "lesson_06_concurrent_dispatch" {
    const scale_shader: [*:0]const u8 =
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

    var device = try zmtl.Device.default();
    const pipeline = try device.createComputePipeline(scale_shader, "scale_kernel");
    var buffer = try device.createBuffer(f32, 8);

    // Initialize with 1..8
    const data = buffer.contents().?;
    for (data, 0..) |*v, i| v.* = @floatFromInt(i + 1);

    // Concurrent dispatch with barrier (x2 then x3 = x6)
    device.submit(
        zmtl.cmd
            .computeConcurrent(pipeline)
            .setBuffer(buffer, 0, .{})
            .setBytes(&Params{ .scale = 2.0, .offset = 0 }, 1)
            .dispatch1d(pipeline, 8)
            .barrier(.buffers) // Required for concurrent when same buffer
            .setBytes(&Params{ .scale = 3.0, .offset = 0 }, 1)
            .dispatch1d(pipeline, 8),
    );

    // Verify: should be [6, 12, 18, 24, 30, 36, 42, 48]
    for (data, 0..) |val, i| {
        try std.testing.expectEqual(@as(f32, @floatFromInt((i + 1) * 6)), val);
    }
}

test "lesson_07_events" {
    const scale_shader: [*:0]const u8 =
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

    var device = try zmtl.Device.default();
    const pipeline = try device.createComputePipeline(scale_shader, "scale_kernel");
    var buffer = try device.createBuffer(f32, 8);

    // Initialize with 1..8
    const data = buffer.contents().?;
    for (data, 0..) |*v, i| v.* = @floatFromInt(i + 1);

    // TODO: Event-based synchronization not yet in comptime API
    // For now, just test sequential async submissions
    _ = zmtl.Event.init(device); // Keep to verify Event.init compiles

    // First submission: x10
    const fence1 = device.submitAsync(
        zmtl.cmd
            .compute(pipeline)
            .setBuffer(buffer, 0, .{})
            .setBytes(&Params{ .scale = 10.0, .offset = 0 }, 1)
            .dispatch1d(pipeline, 8),
    );

    // Wait for first to complete before second (manual sync instead of GPU event)
    fence1.wait();

    // Second submission: x0.1 (back to original)
    const fence2 = device.submitAsync(
        zmtl.cmd
            .compute(pipeline)
            .setBuffer(buffer, 0, .{})
            .setBytes(&Params{ .scale = 0.1, .offset = 0 }, 1)
            .dispatch1d(pipeline, 8),
    );

    fence1.wait();
    fence2.wait();

    // Verify: should be back to approximately [1, 2, 3, 4, 5, 6, 7, 8]
    for (data, 0..) |val, i| {
        try std.testing.expectApproxEqAbs(@as(f32, @floatFromInt(i + 1)), val, 0.01);
    }
}

test "lesson_08_acceleration_structure" {
    var device = try zmtl.Device.default();

    // Skip if ray tracing not supported
    if (!device.supportsRaytracing()) {
        return;
    }

    // Create vertex buffer for a simple triangle (3 vertices * 3 floats)
    const vertices = [_]f32{
        0.0, 0.0, 0.0, // v0
        1.0, 0.0, 0.0, // v1
        0.5, 1.0, 0.0, // v2
    };

    var vertex_buffer = try device.createBuffer(f32, vertices.len);
    @memcpy(vertex_buffer.contents().?, &vertices);

    // Create index buffer
    const indices = [_]u32{ 0, 1, 2 };
    var index_buffer = try device.createBuffer(u32, indices.len);
    @memcpy(index_buffer.contents().?, &indices);

    // Create triangle geometry descriptor
    const triangle_geo = zmtl.TriangleGeometryDescriptor.init()
        .setVertexBuffer(vertex_buffer, .{ .stride = 12 })
        .setIndexBuffer(index_buffer, .uint32, .{})
        .setTriangleCount(1);

    // Create BLAS descriptor
    var blas_desc = zmtl.PrimitiveAccelerationStructureDescriptor.init();
    blas_desc.addGeometry(triangle_geo);
    blas_desc.build();

    // Get sizes
    const sizes = device.getAccelerationStructureSizes(blas_desc);
    try std.testing.expect(sizes.acceleration_structure_size > 0);
    try std.testing.expect(sizes.build_scratch_buffer_size > 0);

    // Create acceleration structure and scratch buffer
    const blas = try device.createAccelerationStructure(sizes.acceleration_structure_size);
    const scratch_buffer = try device.createBuffer(u8, sizes.build_scratch_buffer_size);

    // Build the BLAS
    device.submit(
        zmtl.cmd
            .accel()
            .buildAccelerationStructure(blas, blas_desc, scratch_buffer, .{}),
    );

    // If we got here without crashing, the test passed
    try std.testing.expect(blas.size() > 0);
}

// =============================================================================
// Lesson 05: Image Processing with Textures
// =============================================================================

test "lesson_05_convolution" {
    var device = try zmtl.Device.default();

    // Convolution shader with kernel weights
    const shader_source: [*:0]const u8 =
        \\#include <metal_stdlib>
        \\using namespace metal;
        \\
        \\kernel void convolve(
        \\    texture2d<float, access::read> input [[texture(0)]],
        \\    texture2d<float, access::write> output [[texture(1)]],
        \\    constant float* weights [[buffer(0)]],
        \\    constant int& kernel_radius [[buffer(1)]],
        \\    uint2 gid [[thread_position_in_grid]]
        \\) {
        \\    int width = input.get_width();
        \\    int height = input.get_height();
        \\
        \\    // Bounds check
        \\    if (gid.x >= uint(width) || gid.y >= uint(height)) return;
        \\
        \\    float4 sum = float4(0.0);
        \\    int kernel_size = 2 * kernel_radius + 1;
        \\    int weight_idx = 0;
        \\
        \\    for (int dy = -kernel_radius; dy <= kernel_radius; dy++) {
        \\        for (int dx = -kernel_radius; dx <= kernel_radius; dx++) {
        \\            // Clamp coordinates to texture bounds
        \\            int sx = clamp(int(gid.x) + dx, 0, width - 1);
        \\            int sy = clamp(int(gid.y) + dy, 0, height - 1);
        \\
        \\            float4 sample = input.read(uint2(sx, sy));
        \\            sum += sample * weights[weight_idx];
        \\            weight_idx++;
        \\        }
        \\    }
        \\
        \\    // Clamp result to valid range
        \\    sum = clamp(sum, 0.0, 1.0);
        \\    sum.a = 1.0; // Preserve alpha
        \\    output.write(sum, gid);
        \\}
    ;

    const pipeline = try device.createComputePipeline(shader_source, "convolve");

    const width: u64 = 256;
    const height: u64 = 256;
    const channels: u64 = 4;
    var pixels: [width * height * channels]u8 = undefined;

    // Create a test pattern: white rectangle in center on black background
    for (0..height) |y| {
        for (0..width) |x| {
            const idx = (y * width + x) * channels;
            const in_center = x >= width / 4 and x < 3 * width / 4 and
                y >= height / 4 and y < 3 * height / 4;

            if (in_center) {
                pixels[idx + 0] = 255; // R
                pixels[idx + 1] = 255; // G
                pixels[idx + 2] = 255; // B
                pixels[idx + 3] = 255; // A
            } else {
                pixels[idx + 0] = 0;
                pixels[idx + 1] = 0;
                pixels[idx + 2] = 0;
                pixels[idx + 3] = 255;
            }
        }
    }

    const input_tex = try device.createTexture(width, height, zmtl.PixelFormat.rgba8unorm, zmtl.TextureUsage.read);
    const output_tex = try device.createTexture(width, height, zmtl.PixelFormat.rgba8unorm, zmtl.TextureUsage.write);

    input_tex.upload(&pixels);

    // Save input image
    try input_tex.savePPM("input.ppm", &pixels);

    // Edge detection kernel (Laplacian)
    const kernel_weights = [9]f32{ -1, -1, -1, -1, 8, -1, -1, -1, -1 };
    const kernel_radius: i32 = 1; // 3x3 kernel has radius 1

    device.submit(
        zmtl.cmd
            .compute(pipeline)
            .setTexture(input_tex, 0)
            .setTexture(output_tex, 1)
            .setBytes(&kernel_weights, 0)
            .setBytes(&kernel_radius, 1)
            .dispatch2d(width, height),
    );

    // Read back result
    var result: [width * height * channels]u8 = undefined;
    output_tex.download(&result);

    // Save output image
    try output_tex.savePPM("output.ppm", &result);

    // Verify edge detection worked: center should be black (no edges inside),
    // but the border of the rectangle should have non-zero values
    // Check a pixel on the edge of the white rectangle
    const edge_x = width / 4;
    const edge_y = height / 2;
    const edge_idx = (edge_y * width + edge_x) * channels;

    // Edge pixels should be non-zero (detected edge)
    const edge_brightness = @as(u32, result[edge_idx]) + result[edge_idx + 1] + result[edge_idx + 2];
    try std.testing.expect(edge_brightness > 0);

    // Center pixel should be near zero (no edge in uniform region)
    const center_x = width / 2;
    const center_y = height / 2;
    const center_idx = (center_y * width + center_x) * channels;
    const center_brightness = @as(u32, result[center_idx]) + result[center_idx + 1] + result[center_idx + 2];
    try std.testing.expect(center_brightness < 50); // Allow some tolerance
}
