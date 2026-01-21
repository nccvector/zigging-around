const std = @import("std");
const metal = @import("metal");

// Metal shader source - compiled at runtime
const shader_source =
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

const ARRAY_SIZE: usize = 16 * 1024 * 1024; // 16M elements for better GPU utilization
const WARMUP_ITERS: usize = 3;
const BENCH_ITERS: usize = 10;

pub fn main() !void {
    // Get Metal device
    const device = metal.mtl_create_system_default_device() orelse {
        std.debug.print("Metal not available\n", .{});
        return;
    };
    std.debug.print("Metal GPU Compute Benchmark\n", .{});
    std.debug.print("===========================\n\n", .{});

    // Compile shader from source
    var compile_error: ?*anyopaque = null;
    const library = metal.mtl_device_new_library_with_source_options_error(
        device,
        shader_source,
        null,
        &compile_error,
    ) orelse {
        std.debug.print("Failed to compile shader\n", .{});
        return;
    };

    // Get kernel functions
    const add_fn = metal.mtl_library_new_function_with_name(library, "vector_add") orelse return;
    const mul_fn = metal.mtl_library_new_function_with_name(library, "vector_multiply") orelse return;
    const fma_fn = metal.mtl_library_new_function_with_name(library, "vector_fma") orelse return;

    // Create compute pipelines
    var pipeline_error: ?*anyopaque = null;
    const add_pipeline = metal.mtl_device_new_compute_pipeline_state_with_function_error(device, add_fn, &pipeline_error) orelse return;
    const mul_pipeline = metal.mtl_device_new_compute_pipeline_state_with_function_error(device, mul_fn, &pipeline_error) orelse return;
    const fma_pipeline = metal.mtl_device_new_compute_pipeline_state_with_function_error(device, fma_fn, &pipeline_error) orelse return;

    const max_threads = metal.mtl_computepipelinestate_max_total_threads_per_threadgroup(add_pipeline);
    std.debug.print("Array size: {} elements ({} MB)\n", .{ ARRAY_SIZE, (ARRAY_SIZE * @sizeOf(f32)) / (1024 * 1024) });
    std.debug.print("Max threads/threadgroup: {}\n\n", .{max_threads});

    // Create buffers
    const buffer_size = ARRAY_SIZE * @sizeOf(f32);
    const storage_mode: u64 = 0; // Shared

    const buffer_a = metal.mtl_device_new_buffer_with_length_options(device, buffer_size, storage_mode) orelse return;
    const buffer_b = metal.mtl_device_new_buffer_with_length_options(device, buffer_size, storage_mode) orelse return;
    const buffer_c = metal.mtl_device_new_buffer_with_length_options(device, buffer_size, storage_mode) orelse return;
    const buffer_d = metal.mtl_device_new_buffer_with_length_options(device, buffer_size, storage_mode) orelse return;

    // Get pointers and initialize
    const ptr_a: [*]f32 = @ptrCast(@alignCast(metal.mtl_buffer_contents(buffer_a)));
    const ptr_b: [*]f32 = @ptrCast(@alignCast(metal.mtl_buffer_contents(buffer_b)));
    const ptr_c: [*]f32 = @ptrCast(@alignCast(metal.mtl_buffer_contents(buffer_c)));
    const ptr_d: [*]f32 = @ptrCast(@alignCast(metal.mtl_buffer_contents(buffer_d)));

    for (0..ARRAY_SIZE) |i| {
        ptr_a[i] = @floatFromInt(i % 1000);
        ptr_b[i] = @floatFromInt((i * 7) % 1000);
        ptr_c[i] = @floatFromInt((i * 13) % 1000);
        ptr_d[i] = 0;
    }

    const queue = metal.mtl_device_new_command_queue(device) orelse return;

    // Calculate dispatch sizes
    const threadgroup_size = @min(max_threads, 1024);
    const grid_size = (ARRAY_SIZE + threadgroup_size - 1) / threadgroup_size;

    // =========================================================================
    // Benchmark: Vector Add
    // =========================================================================
    std.debug.print("Vector Add (C = A + B):\n", .{});

    // GPU warmup
    for (0..WARMUP_ITERS) |_| {
        const cmd = metal.mtl_commandqueue_command_buffer(queue) orelse return;
        const enc = metal.mtl_commandbuffer_compute_command_encoder(cmd) orelse return;
        metal.mtl_computecommandencoder_set_compute_pipeline_state(enc, add_pipeline);
        metal.mtl_computecommandencoder_set_buffer_offset_at_index(enc, buffer_a, 0, 0);
        metal.mtl_computecommandencoder_set_buffer_offset_at_index(enc, buffer_b, 0, 1);
        metal.mtl_computecommandencoder_set_buffer_offset_at_index(enc, buffer_c, 0, 2);
        metal.mtl_computecommandencoder_dispatch_threadgroups(enc, grid_size, 1, 1, threadgroup_size, 1, 1);
        metal.mtl_computecommandencoder_end_encoding(enc);
        metal.mtl_commandbuffer_commit(cmd);
        metal.mtl_commandbuffer_wait_until_completed(cmd);
    }

    // GPU benchmark
    var gpu_total: u64 = 0;
    for (0..BENCH_ITERS) |_| {
        var timer = try std.time.Timer.start();
        const cmd = metal.mtl_commandqueue_command_buffer(queue) orelse return;
        const enc = metal.mtl_commandbuffer_compute_command_encoder(cmd) orelse return;
        metal.mtl_computecommandencoder_set_compute_pipeline_state(enc, add_pipeline);
        metal.mtl_computecommandencoder_set_buffer_offset_at_index(enc, buffer_a, 0, 0);
        metal.mtl_computecommandencoder_set_buffer_offset_at_index(enc, buffer_b, 0, 1);
        metal.mtl_computecommandencoder_set_buffer_offset_at_index(enc, buffer_c, 0, 2);
        metal.mtl_computecommandencoder_dispatch_threadgroups(enc, grid_size, 1, 1, threadgroup_size, 1, 1);
        metal.mtl_computecommandencoder_end_encoding(enc);
        metal.mtl_commandbuffer_commit(cmd);
        metal.mtl_commandbuffer_wait_until_completed(cmd);
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
    const gpu_throughput = @as(f64, @floatFromInt(ARRAY_SIZE * @sizeOf(f32) * 3)) / (gpu_ms / 1000.0) / 1e9; // GB/s (read 2, write 1)

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

    // GPU warmup + bench
    for (0..WARMUP_ITERS) |_| {
        const cmd = metal.mtl_commandqueue_command_buffer(queue) orelse return;
        const enc = metal.mtl_commandbuffer_compute_command_encoder(cmd) orelse return;
        metal.mtl_computecommandencoder_set_compute_pipeline_state(enc, mul_pipeline);
        metal.mtl_computecommandencoder_set_buffer_offset_at_index(enc, buffer_a, 0, 0);
        metal.mtl_computecommandencoder_set_buffer_offset_at_index(enc, buffer_b, 0, 1);
        metal.mtl_computecommandencoder_set_buffer_offset_at_index(enc, buffer_c, 0, 2);
        metal.mtl_computecommandencoder_dispatch_threadgroups(enc, grid_size, 1, 1, threadgroup_size, 1, 1);
        metal.mtl_computecommandencoder_end_encoding(enc);
        metal.mtl_commandbuffer_commit(cmd);
        metal.mtl_commandbuffer_wait_until_completed(cmd);
    }

    gpu_total = 0;
    for (0..BENCH_ITERS) |_| {
        var timer = try std.time.Timer.start();
        const cmd = metal.mtl_commandqueue_command_buffer(queue) orelse return;
        const enc = metal.mtl_commandbuffer_compute_command_encoder(cmd) orelse return;
        metal.mtl_computecommandencoder_set_compute_pipeline_state(enc, mul_pipeline);
        metal.mtl_computecommandencoder_set_buffer_offset_at_index(enc, buffer_a, 0, 0);
        metal.mtl_computecommandencoder_set_buffer_offset_at_index(enc, buffer_b, 0, 1);
        metal.mtl_computecommandencoder_set_buffer_offset_at_index(enc, buffer_c, 0, 2);
        metal.mtl_computecommandencoder_dispatch_threadgroups(enc, grid_size, 1, 1, threadgroup_size, 1, 1);
        metal.mtl_computecommandencoder_end_encoding(enc);
        metal.mtl_commandbuffer_commit(cmd);
        metal.mtl_commandbuffer_wait_until_completed(cmd);
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
    // Benchmark: FMA (Fused Multiply-Add)
    // =========================================================================
    std.debug.print("Fused Multiply-Add (D = A * B + C):\n", .{});

    // GPU warmup + bench
    for (0..WARMUP_ITERS) |_| {
        const cmd = metal.mtl_commandqueue_command_buffer(queue) orelse return;
        const enc = metal.mtl_commandbuffer_compute_command_encoder(cmd) orelse return;
        metal.mtl_computecommandencoder_set_compute_pipeline_state(enc, fma_pipeline);
        metal.mtl_computecommandencoder_set_buffer_offset_at_index(enc, buffer_a, 0, 0);
        metal.mtl_computecommandencoder_set_buffer_offset_at_index(enc, buffer_b, 0, 1);
        metal.mtl_computecommandencoder_set_buffer_offset_at_index(enc, buffer_c, 0, 2);
        metal.mtl_computecommandencoder_set_buffer_offset_at_index(enc, buffer_d, 0, 3);
        metal.mtl_computecommandencoder_dispatch_threadgroups(enc, grid_size, 1, 1, threadgroup_size, 1, 1);
        metal.mtl_computecommandencoder_end_encoding(enc);
        metal.mtl_commandbuffer_commit(cmd);
        metal.mtl_commandbuffer_wait_until_completed(cmd);
    }

    gpu_total = 0;
    for (0..BENCH_ITERS) |_| {
        var timer = try std.time.Timer.start();
        const cmd = metal.mtl_commandqueue_command_buffer(queue) orelse return;
        const enc = metal.mtl_commandbuffer_compute_command_encoder(cmd) orelse return;
        metal.mtl_computecommandencoder_set_compute_pipeline_state(enc, fma_pipeline);
        metal.mtl_computecommandencoder_set_buffer_offset_at_index(enc, buffer_a, 0, 0);
        metal.mtl_computecommandencoder_set_buffer_offset_at_index(enc, buffer_b, 0, 1);
        metal.mtl_computecommandencoder_set_buffer_offset_at_index(enc, buffer_c, 0, 2);
        metal.mtl_computecommandencoder_set_buffer_offset_at_index(enc, buffer_d, 0, 3);
        metal.mtl_computecommandencoder_dispatch_threadgroups(enc, grid_size, 1, 1, threadgroup_size, 1, 1);
        metal.mtl_computecommandencoder_end_encoding(enc);
        metal.mtl_commandbuffer_commit(cmd);
        metal.mtl_commandbuffer_wait_until_completed(cmd);
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
    const fma_throughput = @as(f64, @floatFromInt(ARRAY_SIZE * @sizeOf(f32) * 4)) / (gpu_fma_ms / 1000.0) / 1e9; // read 3, write 1

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
