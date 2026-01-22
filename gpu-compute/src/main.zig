const std = @import("std");
const mtl = @cImport({
    @cInclude("metal_wrapper.h");
});

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

    const device = mtl.MTLWrapperCreateSystemDefaultDevice() orelse {
        std.debug.print("Metal device not available\n", .{});
        return error.MetalDeviceCreationFailure;
    };

    var compile_error: mtl.NSErrorRef = null;
    const library = mtl.MTLDeviceNewLibraryWithSource(device, shader_source, null, &compile_error) orelse {
        const desc: [*c]const u8 = mtl.NSErrorLocalizedDescription(compile_error) orelse "(unknown error)";
        std.debug.print("Failed to compile shader: {s}", .{desc});
        return error.ShaderCompilationFailed;
    };

    const hello = mtl.MTLLibraryNewFunctionWithName(library, "hello") orelse {
        std.debug.print("Failed to get hello kernel", .{});
        return error.KernelCreationFailed;
    };

    var pipeline_error: mtl.NSErrorRef = null;
    const hello_pipeline = mtl.MTLDeviceNewComputePipelineStateWithFunction(device, hello, &pipeline_error) orelse {
        const desc: [*c]const u8 = mtl.NSErrorLocalizedDescription(compile_error) orelse "(unknown error)";
        std.debug.print("Failed to create pipeline state: {s}", .{desc});
        return error.HelloPipelineCreationFailure;
    };

    const buffer = mtl.MTLDeviceNewBufferWithLength(device, array_len * @sizeOf(f32), 0) orelse {
        std.debug.print("Failed to create buffer", .{});
        return error.BufferCreationFailure;
    };

    const queue = mtl.MTLDeviceNewCommandQueue(device) orelse {
        std.debug.print("Failed to create command queue", .{});
        return error.CommandQueueCreationFailure;
    };

    const command = mtl.MTLCommandQueueCommandBuffer(queue) orelse return error.CommandCreationFailure;

    const encoder = mtl.MTLCommandBufferComputeCommandEncoder(command) orelse return error.CommandEncoderCreationFailure;

    mtl.MTLComputeCommandEncoderSetComputePipelineState(encoder, hello_pipeline);

    mtl.MTLComputeCommandEncoderSetBuffer(encoder, buffer, 0, 0);

    const max_threads = mtl.MTLComputePipelineStateMaxTotalThreadsPerThreadgroup(hello_pipeline);
    const num_groups = try std.math.divCeil(u64, array_len, max_threads);
    const groups = mtl.MTLSize{ .width = num_groups, .height = 1, .depth = 1 };
    const threads_per_group = mtl.MTLSize{ .width = max_threads, .height = 1, .depth = 1 };
    mtl.MTLComputeCommandEncoderDispatchThreadgroups(
        encoder,
        groups,
        threads_per_group,
    );

    mtl.MTLComputeCommandEncoderEndEncoding(encoder);
    mtl.MTLCommandBufferCommit(command);
    mtl.MTLCommandBufferWaitUntilCompleted(command);

    const output: [*]f32 = @ptrCast(@alignCast(mtl.MTLBufferContents(buffer)));
    for (0..array_len) |i| {
        try std.testing.expectEqual(@as(f32, 42.0), output[i]);
    }
}
