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

```
ComputeEncoder
  ├── setPipeline(A)
  ├── setBuffer(...)
  ├── dispatch(...)      ← runs pipeline A
  ├── setPipeline(B)     ← switch pipeline (cheap!)
  ├── setBuffer(...)
  └── dispatch(...)      ← runs pipeline B
```

**Performance benefit**: Single encoder submission has less CPU overhead than multiple submissions.

### What CAN Be Mixed (Single CommandBuffer)

A single CommandBuffer can contain multiple encoder types:

```
CommandBuffer
  ├── ComputeEncoder → dispatch, dispatch, ...
  ├── BlitEncoder    → copy, fill, ...
  └── ComputeEncoder → dispatch, ...
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

```
// Concurrent mode - dispatches can overlap
ConcurrentComputeEncoder
  ├── dispatch(A)       ←
  ├── dispatch(B)       ← A and B may run in parallel
  ├── barrier(.buffers) ← wait for A,B to complete
  └── dispatch(C)       ← C runs after barrier
```

**When to use concurrent**: When you have multiple independent dispatches that don't share data, or when you explicitly manage dependencies with barriers.

---

## Submission Patterns

### Synchronous vs Asynchronous

**Synchronous** (blocking):
```
submit(command)  // CPU blocks until GPU finishes
```

**Asynchronous** (non-blocking):
```
fence = submitAsync(command)  // Returns immediately
// ... do other CPU work ...
fence.wait()  // Block when you need the result
```

### Batching Multiple Submissions

You can submit multiple command buffers without waiting:

```
fence1 = submitAsync(cmd1)
fence2 = submitAsync(cmd2)
fence3 = submitAsync(cmd3)
// GPU processes all three, potentially in parallel across queues
fence3.wait()  // Wait for all to complete
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

```
Grid: (imageWidth/16, imageHeight/16, 1)
ThreadsPerGroup: (16, 16, 1)
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

### Acceleration Structures
Ray tracing primitives (BVH). Build once, trace many rays efficiently.

### Mesh Shaders
Modern geometry pipeline (object → mesh → fragment). More flexible than vertex shaders for procedural geometry.

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
