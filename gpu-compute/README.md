# Metal Compute API - Learnings & Performance Patterns

This document captures key learnings from exploring Metal's compute API, with a focus on understanding parallelism, batching, and performance implications.

## Core Concepts

### Command Structure

Metal uses a hierarchical command structure:

```
Device
  └── CommandQueue (reusable, typically create once)
        └── CommandBuffer (one-shot, created per submission)
              └── CommandEncoder (compute, blit, render, etc.)
                    └── Operations (dispatch, copy, etc.)
```

**Key insight**: CommandBuffers are lightweight and meant to be created frequently. CommandQueues are heavyweight and should be reused.

---

## Parallelism & Batching

### What CAN Be Batched (Single Encoder)

Within a single compute encoder, you can batch:

- **Multiple dispatches** with the same pipeline
- **Pipeline switches** - change pipeline state between dispatches
- **Buffer/texture bindings** - rebind resources between dispatches
- **Barriers** - synchronize memory access between dispatches

This all happens in one encoder, submitted as one unit:

```zig
var cmd = try device.command();
{
    var enc = cmd.computeEncoder(pipelineA, .{});
    defer enc.end();

    enc.buffer(..., 0);
    enc.dispatch1d(...);      // runs pipeline A
    enc.pipeline(pipelineB);  // switch pipeline (cheap!)
    enc.buffer(..., 0);
    enc.dispatch1d(...);      // runs pipeline B
}
```

**Performance benefit**: Single encoder submission has less CPU overhead than multiple submissions.

### What CAN Be Mixed (Single CommandBuffer)

A single CommandBuffer can contain multiple encoder types:

```zig
var cmd = try device.command();

// Compute pass
{
    var enc = cmd.computeEncoder(pipeline, .{});
    defer enc.end();
    enc.dispatch1d(...);
    enc.dispatch1d(...);
}

// Blit pass
{
    var enc = cmd.blitEncoder();
    defer enc.end();
    enc.copy(src, dst);
}

// Another compute pass
{
    var enc = cmd.computeEncoder(pipeline, .{});
    defer enc.end();
    enc.dispatch1d(...);
}

device.submit(&cmd);
```

Metal automatically handles encoder transitions. The GPU executes encoders sequentially within a command buffer.

### Serial vs Concurrent Dispatch

Metal supports two dispatch modes within a compute encoder:

**Serial (default)**:
- Dispatches execute one after another
- Implicit synchronization between dispatches
- Safe for read-after-write on same buffer

**Concurrent**:
- Dispatches MAY execute in parallel
- No implicit synchronization
- Must use explicit barriers for dependencies
- Better GPU utilization when dispatches are independent

```zig
// Concurrent mode - dispatches can overlap
var cmd = try device.command();
{
    var enc = cmd.computeEncoder(pipeline, .{ .concurrent = true });
    defer enc.end();

    enc.dispatch1d(...);     // dispatch A
    enc.dispatch1d(...);     // dispatch B (may run parallel with A)
    enc.barrier(.buffers);   // wait for A,B to complete
    enc.dispatch1d(...);     // dispatch C (runs after barrier)
}
```

**When to use concurrent**: When you have multiple independent dispatches that don't share data, or when you explicitly manage dependencies with barriers.

---

## Submission Patterns

### Synchronous vs Asynchronous

**Synchronous** (blocking):
```zig
var cmd = try device.command();
// ... encode work ...
device.submit(&cmd);  // CPU blocks until GPU finishes
```

**Asynchronous** (non-blocking):
```zig
var cmd = try device.command();
// ... encode work ...
const fence = device.submitAsync(&cmd);  // Returns immediately
// ... do other CPU work ...
fence.wait();  // Block when you need the result
```

### Batching Multiple Submissions

You can submit multiple command buffers without waiting:

```zig
var cmd1 = try device.command();
// ... encode work 1 ...
const fence1 = device.submitAsync(&cmd1);

var cmd2 = try device.command();
// ... encode work 2 ...
const fence2 = device.submitAsync(&cmd2);

var cmd3 = try device.command();
// ... encode work 3 ...
const fence3 = device.submitAsync(&cmd3);

// GPU processes all three, potentially in parallel across queues
fence3.wait();  // Wait for all to complete
```

**Important**: Command buffers submitted to the SAME queue execute in order. Use multiple queues for true parallelism across command buffers.

---

## Memory & Synchronization

### Buffer Storage Modes

| Mode | CPU Access | GPU Access | Use Case |
|------|-----------|------------|----------|
| Shared | Read/Write | Read/Write | Small buffers, frequent CPU access |
| Private | None | Read/Write | GPU-only data, best performance |
| Managed | Read/Write | Read/Write | Large buffers, explicit sync (macOS) |

**Performance tip**: Use Private storage for intermediate GPU buffers. Use Shared only when CPU needs access.

### Barrier Scopes

Barriers synchronize memory access within concurrent encoders:

- `.buffers` - Synchronize buffer read/writes
- `.textures` - Synchronize texture read/writes
- `.renderTargets` - Synchronize render target access

**When barriers are needed**: Only in concurrent dispatch mode when a later dispatch reads data written by an earlier dispatch.

---

## Textures & Images

### Texture Usage Flags

Textures must declare their usage upfront:

- `read` - Shader can sample/read
- `write` - Shader can write
- `read | write` - Shader can do both

### 2D Dispatch Pattern

For image processing, dispatch a 2D grid:

```zig
enc.dispatch2d(imageWidth, imageHeight);
// Automatically uses 16x16 threadgroups
```

Each thread processes one pixel. The 16x16 group size is a common sweet spot for most GPUs.

---

## Performance Hierarchy (Fast → Slow)

1. **Same encoder, same pipeline**: Just dispatch again
2. **Same encoder, different pipeline**: setPipeline + dispatch
3. **Same command buffer, different encoder**: End encoder, begin new one
4. **Different command buffer, same queue**: Sequential execution
5. **Different queue**: True parallelism, but more CPU overhead

---

## Ray Tracing & Acceleration Structures

### Two-Level Hierarchy (BLAS/TLAS)

Metal ray tracing uses a two-level acceleration structure:

```
TLAS (Top-Level Acceleration Structure)
  ├── Instance 0 → BLAS A + Transform
  ├── Instance 1 → BLAS A + Transform  (same geometry, different position)
  ├── Instance 2 → BLAS B + Transform
  └── Instance 3 → BLAS C + Transform
```

**BLAS (Bottom-Level)**: Contains actual geometry (triangles/bounding boxes) in local object space. Built once per unique mesh.

**TLAS (Top-Level)**: Contains instances that reference BLASes with transforms. Rebuilt/updated per frame as objects move.

**Key benefit**: A mesh used 1000 times only needs ONE BLAS. The TLAS has 1000 instances pointing to it with different transforms. Massive memory savings.

### Build Strategies

| Structure | Static Scene | Dynamic Scene |
|-----------|-------------|---------------|
| BLAS | PREFER_FAST_TRACE | PREFER_FAST_BUILD (if geometry changes) |
| TLAS | PREFER_FAST_TRACE | PREFER_FAST_BUILD (usually) |

**Why TLAS prefers FAST_BUILD**: TLASes are typically rebuilt every frame as objects move. The build cost matters more than trace cost since the structure is short-lived.

**Why BLAS prefers FAST_TRACE**: BLASes for static geometry live for many frames. Investing in build quality pays off over thousands of ray queries.

### Large Scene Best Practices

**1. Instance Culling for TLAS**
Don't include the entire scene in your TLAS. Cull based on:
- Camera frustum (expanded slightly for reflections/shadows)
- Maximum distance (can be less than rasterization far plane)
- Object size (small objects culled at shorter distances)

**2. BLAS Organization**
- Fewer large BLASes > many small BLASes
- Merge geometries whose world-space bounding boxes overlap
- Avoid empty space inside BLAS (increases AABB hit tests)
- Reduce overlapping between different BLASes

**3. LOD for Ray Tracing**
- Use simpler geometry for distant objects
- Consider matching rasterization LOD (avoids self-intersection artifacts)
- Lower detail LODs reduce dynamic BLAS update costs

**4. Memory & Instancing**
- Instance identical geometry instead of duplicating
- Each instance can have unique materials and transforms
- Instancing saves memory AND improves trace performance

### Batching Acceleration Structure Operations

Within a single accel encoder, you can batch:
```zig
var cmd = try device.command();
{
    var enc = cmd.accelEncoder();
    defer enc.end();

    enc.build(blas_a, blas_a_desc, scratch_a);
    enc.build(blas_b, blas_b_desc, scratch_b);
    enc.build(blas_c, blas_c_desc, scratch_c);  // All BLAS builds can overlap
    enc.barrier();                              // Wait for BLAS builds
    enc.build(tlas, tlas_desc, scratch_tlas);   // TLAS references the BLASes
}
```

**Critical**: Only ONE barrier needed between all BLAS builds and TLAS build. Don't over-synchronize.

### Update vs Rebuild

| Operation | When to Use |
|-----------|------------|
| **Rebuild** | Geometry topology changed, or major structural changes |
| **Refit** | Same topology, vertices just moved (animation) |

Refit is faster but produces lower-quality acceleration structure. For skinned meshes with subtle animation, refit is usually fine. For explosions or major deformations, rebuild.

### Compaction

After building, acceleration structures often have wasted space. Compaction shrinks them:

```zig
// 1. Build BLAS (oversized)
var cmd1 = try device.command();
{
    var enc = cmd1.accelEncoder();
    defer enc.end();
    enc.build(blas, desc, scratch);
    enc.writeCompactedSize(blas, size_buf, 0);
}
device.submit(&cmd1);

// 2. Read compacted size and allocate smaller buffer
const compacted_size = size_buf.contents().?[0];
const compacted_blas = try device.accelerationStructure(compacted_size);

// 3. Compact
var cmd2 = try device.command();
{
    var enc = cmd2.accelEncoder();
    defer enc.end();
    enc.compact(blas, compacted_blas);
}
device.submit(&cmd2);
```

**When to compact**: Static geometry that will be used for many frames. Not worth it for frequently rebuilt structures.

### Performance Targets

For real-time ray tracing:
- Aim for BLAS/TLAS build + update under **2ms per frame**
- Overlap accel builds with other work (G-buffer, shadow maps) using async compute
- Profile and prune aggressively

---

## What We Haven't Covered Yet

### Indirect Dispatch
GPU-driven dispatch counts - the GPU itself determines how many threadgroups to launch based on buffer contents. Useful for variable workloads.

### Threadgroup Memory
Shared memory within a threadgroup for fast inter-thread communication. Essential for reductions, scans, and tiled algorithms.

### SIMD Group Functions
Warp/wavefront-level operations (shuffle, reduce) that are faster than threadgroup memory for small data sharing.

### Argument Buffers
Pack multiple resource bindings into a buffer. Reduces CPU overhead when binding many resources.

### Resource Heaps
Pre-allocate GPU memory and sub-allocate from it. Reduces allocation overhead for dynamic resource creation.

### Mesh Shaders
Modern geometry pipeline (object → mesh → fragment). More flexible than vertex shaders for procedural geometry.

### Intersection Functions
Custom ray-primitive intersection for non-triangle geometry (curves, procedural shapes).

---

## Quick Reference: Batching Decisions

| Scenario | Recommendation |
|----------|---------------|
| Same pipeline, multiple dispatches | Batch in one encoder |
| Different pipelines, sequential data flow | Batch in one encoder, use setPipeline |
| Independent compute + blit | Batch in one command buffer |
| Truly independent workloads | Separate command buffers, async submit |
| Need GPU to determine dispatch size | Use indirect dispatch |
| Processing images | Use textures with 2D dispatch |
| Large data, CPU doesn't need it | Use Private storage mode |
