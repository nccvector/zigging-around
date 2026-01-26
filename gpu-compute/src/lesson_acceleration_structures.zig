const std = @import("std");
const metal = @import("metal.zig");

// =============================================================================
// LESSON 3: Acceleration Structures (Ray Tracing)
// =============================================================================
//
// GOAL: Build a BVH acceleration structure and trace rays against triangles
//
// KEY CONCEPTS:
// - BLAS (Bottom-Level Acceleration Structure) - holds triangle geometry
// - TLAS (Top-Level Acceleration Structure) - references BLAS with transforms
// - Ray intersection queries in compute shaders
//
// SIMPLIFIED API:
//   // Single BLAS
//   const blas = cmd.buildBLAS(.{ .vertices = vertex_buf });
//
//   // Multiple BLASes in batch (efficient - single encoder)
//   const blases = cmd.buildBLASes(.{
//       .{ .vertices = mesh1_verts },
//       .{ .vertices = mesh2_verts },
//   });
//
//   // TLAS from instances
//   const tlas = cmd.buildTLAS(.{ .instances = inst_buf, .blas = &.{blas1, blas2} });
//
// =============================================================================

const Vec3 = packed struct {
    x: f32,
    y: f32,
    z: f32,
};

// Output from ray intersection
const HitResult = packed struct {
    distance: f32, // -1 if no hit
    u: f32, // barycentric u
    v: f32, // barycentric v
    primitive_id: u32, // which triangle was hit
};

// Ray definition for the shader
const Ray = packed struct {
    origin: Vec3,
    min_distance: f32,
    direction: Vec3,
    max_distance: f32,
};

pub fn main() !void {
    const device = try metal.Device.create();

    std.debug.print("=== Lesson 3: Acceleration Structures ===\n", .{});
    std.debug.print("Device: {s}\n\n", .{device.name().?});

    // Check ray tracing support
    if (!device.supportsRaytracing()) {
        std.debug.print("ERROR: This device does not support ray tracing!\n", .{});
        return;
    }

    // -------------------------------------------------------------------------
    // STEP 1: Define scene geometry
    // -------------------------------------------------------------------------
    // A simple quad made of 2 triangles at z=0, facing toward +Z
    //
    //   (-1,1)-----(1,1)
    //      | \       |
    //      |   \     |
    //      |     \   |
    //      |       \ |
    //   (-1,-1)----(1,-1)

    const vertices = [_]Vec3{
        // Triangle 0
        .{ .x = -1, .y = -1, .z = 0 },
        .{ .x = 1, .y = -1, .z = 0 },
        .{ .x = 1, .y = 1, .z = 0 },
        // Triangle 1
        .{ .x = -1, .y = -1, .z = 0 },
        .{ .x = 1, .y = 1, .z = 0 },
        .{ .x = -1, .y = 1, .z = 0 },
    };

    const vertex_buf = try device.createBuffer(Vec3, vertices.len, .{});
    @memcpy(vertex_buf.getHostSlice().?, &vertices);

    // -------------------------------------------------------------------------
    // STEP 2: Build BLAS
    // -------------------------------------------------------------------------
    var build_cmd = try device.createCommand();
    const blas = build_cmd.buildBLAS(.{ .vertices = vertex_buf });
    device.submit(&build_cmd);

    std.debug.print("BLAS built: {d} bytes\n", .{blas.size()});

    // -------------------------------------------------------------------------
    // STEP 3: Define rays to trace
    // -------------------------------------------------------------------------
    // A 4x4 grid of rays shooting from z=5 toward z=0
    // Corner rays miss, center rays hit

    const IMAGE_WIDTH = 4;
    const IMAGE_HEIGHT = 4;
    const NUM_RAYS = IMAGE_WIDTH * IMAGE_HEIGHT;

    var rays: [NUM_RAYS]Ray = undefined;
    for (0..IMAGE_HEIGHT) |y| {
        for (0..IMAGE_WIDTH) |x| {
            const i = y * IMAGE_WIDTH + x;
            // Map pixel to world coordinates: [-1.5, 1.5] range
            const world_x = (@as(f32, @floatFromInt(x)) - 1.5) * 1.0;
            const world_y = (@as(f32, @floatFromInt(y)) - 1.5) * 1.0;

            rays[i] = .{
                .origin = .{ .x = world_x, .y = world_y, .z = 5.0 },
                .direction = .{ .x = 0, .y = 0, .z = -1 },
                .min_distance = 0.001,
                .max_distance = 100.0,
            };
        }
    }

    const ray_buf = try device.createBuffer(Ray, NUM_RAYS, .{});
    @memcpy(ray_buf.getHostSlice().?, &rays);

    const hit_buf = try device.createBuffer(HitResult, NUM_RAYS, .{});

    // -------------------------------------------------------------------------
    // STEP 4: Ray tracing shader
    // -------------------------------------------------------------------------
    const shader_source =
        \\#include <metal_stdlib>
        \\#include <metal_raytracing>
        \\using namespace metal;
        \\using namespace raytracing;
        \\
        \\struct Ray {
        \\    packed_float3 origin;
        \\    float min_distance;
        \\    packed_float3 direction;
        \\    float max_distance;
        \\};
        \\
        \\struct HitResult {
        \\    float distance;
        \\    float u;
        \\    float v;
        \\    uint primitive_id;
        \\};
        \\
        \\kernel void trace_rays(
        \\    device const Ray* rays [[buffer(0)]],
        \\    device HitResult* hits [[buffer(1)]],
        \\    primitive_acceleration_structure accel [[buffer(2)]],
        \\    uint tid [[thread_position_in_grid]]
        \\) {
        \\    // Create intersector
        \\    intersector<triangle_data> i;
        \\
        \\    // Build ray from input
        \\    ray r;
        \\    r.origin = float3(rays[tid].origin);
        \\    r.direction = float3(rays[tid].direction);
        \\    r.min_distance = rays[tid].min_distance;
        \\    r.max_distance = rays[tid].max_distance;
        \\
        \\    // Perform intersection
        \\    auto result = i.intersect(r, accel);
        \\
        \\    // Write results
        \\    if (result.type == intersection_type::triangle) {
        \\        hits[tid].distance = result.distance;
        \\        hits[tid].u = result.triangle_barycentric_coord.x;
        \\        hits[tid].v = result.triangle_barycentric_coord.y;
        \\        hits[tid].primitive_id = result.primitive_id;
        \\    } else {
        \\        hits[tid].distance = -1;
        \\        hits[tid].u = 0;
        \\        hits[tid].v = 0;
        \\        hits[tid].primitive_id = 0;
        \\    }
        \\}
    ;

    const pipeline = try device.createPipeline(shader_source, "trace_rays");

    // -------------------------------------------------------------------------
    // STEP 5: Execute ray tracing
    // -------------------------------------------------------------------------
    var cmd = try device.createCommand();
    var enc = cmd.createComputeEncoder(.{});
    enc.dispatch1d(pipeline, NUM_RAYS, .{
        .buffers = .{
            .{ .buf = ray_buf, .index = 0 },
            .{ .buf = hit_buf, .index = 1 },
        },
        .accels = .{
            .{ .accel = blas.handle, .index = 2 },
        },
    }).end();
    device.submit(&cmd);

    // -------------------------------------------------------------------------
    // STEP 6: Read results
    // -------------------------------------------------------------------------
    const hits = hit_buf.getHostSlice().?;

    std.debug.print("\nRay tracing results (X=hit, .=miss):\n", .{});
    for (0..IMAGE_HEIGHT) |y| {
        for (0..IMAGE_WIDTH) |x| {
            const i = y * IMAGE_WIDTH + x;
            if (hits[i].distance > 0) {
                std.debug.print("X ", .{});
            } else {
                std.debug.print(". ", .{});
            }
        }
        std.debug.print("\n", .{});
    }

    // Print detailed hit info
    std.debug.print("\nDetailed hits:\n", .{});
    for (0..NUM_RAYS) |i| {
        if (hits[i].distance > 0) {
            std.debug.print("  Ray {d}: distance={d:.2}, triangle={d}, uv=({d:.2},{d:.2})\n", .{
                i,
                hits[i].distance,
                hits[i].primitive_id,
                hits[i].u,
                hits[i].v,
            });
        }
    }
}
