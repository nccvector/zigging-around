// src/metal.zig - Idiomatic Zig wrapper for Metal compute

const std = @import("std");
pub const mtl = @cImport({
    @cInclude("metal_wrapper.h");
});

pub const Error = error{
    DeviceNotFound,
    ShaderCompilationFailed,
    FunctionNotFound,
    PipelineCreationFailed,
    BufferCreationFailed,
    CommandQueueCreationFailed,
    CommandBufferCreationFailed,
    EncoderCreationFailed,
    AccelerationStructureCreationFailed,
};

const MAX_QUEUES = 4;

pub const Device = struct {
    handle: mtl.MTLDeviceRef,
    queues: [MAX_QUEUES]mtl.MTLCommandQueueRef,
    next_queue: usize = 0,

    pub fn default() Error!Device {
        const handle = mtl.MTLWrapperCreateSystemDefaultDevice() orelse return error.DeviceNotFound;

        // Pre-create queue pool
        var queues: [MAX_QUEUES]mtl.MTLCommandQueueRef = undefined;
        for (&queues) |*q| {
            q.* = mtl.MTLDeviceNewCommandQueue(handle) orelse return error.CommandQueueCreationFailed;
        }

        return .{
            .handle = handle,
            .queues = queues,
        };
    }

    pub fn name(self: Device) ?[*:0]const u8 {
        return mtl.MTLDeviceName(self.handle);
    }

    pub fn hasUnifiedMemory(self: Device) bool {
        return mtl.MTLDeviceHasUnifiedMemory(self.handle);
    }

    pub fn createBuffer(self: Device, comptime T: type, count: usize) Error!Buffer(T) {
        return self.createBufferWithMode(T, count, .shared);
    }

    pub fn createBufferWithMode(self: Device, comptime T: type, count: usize, mode: StorageMode) Error!Buffer(T) {
        const buffer_handle = mtl.MTLDeviceNewBufferWithLength(self.handle, count * @sizeOf(T), mode.toResourceOptions()) orelse return error.BufferCreationFailed;
        return .{
            .handle = buffer_handle,
            .len = count,
            .storage_mode = mode,
        };
    }

    /// Check if device supports ray tracing
    pub fn supportsRaytracing(self: Device) bool {
        return mtl.MTLDeviceSupportsRaytracing(self.handle);
    }

    /// Create a 2D texture with the specified dimensions and format
    pub fn createTexture(self: Device, width: u64, height: u64, format: PixelFormat, usage: u32) Error!Texture {
        const desc = mtl.MTLTextureDescriptorCreate();
        mtl.MTLTextureDescriptorSetTextureType(desc, mtl.MTLTextureType2D);
        mtl.MTLTextureDescriptorSetPixelFormat(desc, @intFromEnum(format));
        mtl.MTLTextureDescriptorSetWidth(desc, width);
        mtl.MTLTextureDescriptorSetHeight(desc, height);
        mtl.MTLTextureDescriptorSetUsage(desc, usage);
        mtl.MTLTextureDescriptorSetStorageMode(desc, mtl.MTLResourceStorageModeShared);

        const handle = mtl.MTLDeviceNewTextureWithDescriptor(self.handle, desc) orelse return error.BufferCreationFailed;
        return .{
            .handle = handle,
            .width = width,
            .height = height,
            .pixel_format = format,
        };
    }

    /// Create a compute pipeline from shader source and kernel name
    /// TODO: Can implement a library cache in future. Cache based on source hash to avoid re-compilation and reusing the same library.
    pub fn createComputePipeline(self: Device, source: [*:0]const u8, kernel_name: [*:0]const u8) Error!ComputePipeline {
        // Compile shader to library
        var compile_error: mtl.NSErrorRef = null;
        const library = mtl.MTLDeviceNewLibraryWithSource(self.handle, source, null, &compile_error) orelse {
            const desc: [*c]const u8 = mtl.NSErrorLocalizedDescription(compile_error) orelse "(unknown error)";
            std.debug.print("Failed to compile shader: {s}\n", .{desc});
            return error.ShaderCompilationFailed;
        };

        // Get kernel function
        const func = mtl.MTLLibraryNewFunctionWithName(library, kernel_name) orelse return error.FunctionNotFound;

        // Create pipeline
        var pipeline_error: mtl.NSErrorRef = null;
        const pipeline_handle = mtl.MTLDeviceNewComputePipelineStateWithFunction(self.handle, func, &pipeline_error) orelse {
            const desc: [*c]const u8 = mtl.NSErrorLocalizedDescription(pipeline_error) orelse "(unknown error)";
            std.debug.print("Failed to create pipeline: {s}\n", .{desc});
            return error.PipelineCreationFailed;
        };

        return .{ .handle = pipeline_handle };
    }

    /// Get acceleration structure sizes for a descriptor
    pub fn getAccelerationStructureSizes(self: Device, descriptor: anytype) AccelerationStructureSizes {
        const desc_handle = if (@hasField(@TypeOf(descriptor), "handle")) descriptor.handle else descriptor;
        const sizes = mtl.MTLDeviceGetAccelerationStructureSizes(self.handle, desc_handle);
        return .{
            .acceleration_structure_size = sizes.accelerationStructureSize,
            .build_scratch_buffer_size = sizes.buildScratchBufferSize,
            .refit_scratch_buffer_size = sizes.refitScratchBufferSize,
        };
    }

    /// Create an acceleration structure with a specific size
    pub fn createAccelerationStructure(self: Device, size: u64) Error!AccelerationStructure {
        const handle = mtl.MTLDeviceNewAccelerationStructureWithSize(self.handle, size) orelse return error.AccelerationStructureCreationFailed;
        return .{ .handle = handle };
    }

    /// Create an acceleration structure from a descriptor (gets size automatically)
    pub fn createAccelerationStructureWithDescriptor(self: Device, descriptor: anytype) Error!AccelerationStructure {
        const desc_handle = if (@hasField(@TypeOf(descriptor), "handle")) descriptor.handle else descriptor;
        const handle = mtl.MTLDeviceNewAccelerationStructureWithDescriptor(self.handle, desc_handle) orelse return error.AccelerationStructureCreationFailed;
        return .{ .handle = handle };
    }

    /// Get next queue from pool (round-robin)
    fn nextQueue(self: *Device) mtl.MTLCommandQueueRef {
        const queue = self.queues[self.next_queue];
        self.next_queue = (self.next_queue + 1) % MAX_QUEUES;
        return queue;
    }

    /// Submit commands to same queue (sequential), wait for completion
    pub fn submit(self: *Device, commands: []const Command) void {
        const queue = self.nextQueue();

        var last_cmd_buf: ?mtl.MTLCommandBufferRef = null;
        for (commands) |cmd| {
            var c = cmd;
            last_cmd_buf = c.finalize(queue);
        }

        // Wait for last command to complete
        if (last_cmd_buf) |buf| {
            mtl.MTLCommandBufferWaitUntilCompleted(buf);
        }
    }

    /// Submit commands to same queue (sequential), return fence
    pub fn submitAsync(self: *Device, commands: []const Command) Fence {
        const queue = self.nextQueue();

        var last_cmd_buf: ?mtl.MTLCommandBufferRef = null;
        for (commands) |cmd| {
            var c = cmd;
            last_cmd_buf = c.finalize(queue);
        }

        return Fence{ .command_buffer = last_cmd_buf };
    }
};

pub fn Buffer(comptime T: type) type {
    return struct {
        handle: mtl.MTLBufferRef,
        len: usize,
        storage_mode: StorageMode = .shared,

        const Self = @This();

        /// Get a slice to the buffer contents (CPU-accessible for shared/managed storage)
        /// Returns null for private storage mode (GPU-only).
        pub fn contents(self: Self) ?[]T {
            if (self.storage_mode == .private) return null;
            const ptr: [*]T = @ptrCast(@alignCast(mtl.MTLBufferContents(self.handle)));
            return ptr[0..self.len];
        }

        /// Get the buffer size in bytes (useful for blit operations)
        pub fn byteSize(self: Self) u64 {
            return self.len * @sizeOf(T);
        }

        /// For managed storage: notify GPU that CPU modified a range.
        /// Call after writing to contents() on macOS with managed mode.
        pub fn didModifyRange(self: Self, offset: usize, length: usize) void {
            if (self.storage_mode == .managed) {
                mtl.MTLBufferDidModifyRange(self.handle, offset * @sizeOf(T), length * @sizeOf(T));
            }
        }
    };
}

pub const ComputePipeline = struct {
    handle: mtl.MTLComputePipelineStateRef,

    /// Get max threads per threadgroup for this pipeline
    pub fn maxThreadsPerThreadGroup(self: ComputePipeline) u64 {
        return mtl.MTLComputePipelineStateMaxTotalThreadsPerThreadgroup(self.handle);
    }

    /// Calculate optimal grid and threadgroup size for 1D dispatch
    /// Returns .{ grid, threads_per_group }
    pub fn gridFor1d(self: ComputePipeline, element_count: usize) struct { Size, Size } {
        const threads_per_group = self.maxThreadsPerThreadGroup();
        const num_groups = (element_count + threads_per_group - 1) / threads_per_group;
        return .{
            Size{ .width = num_groups },
            Size{ .width = threads_per_group },
        };
    }
};

pub const Size = struct {
    width: u64,
    height: u64 = 1,
    depth: u64 = 1,

    pub fn init1d(width: u64) Size {
        return .{
            .width = width,
        };
    }
};

// =============================================================================
// Acceleration Structures (Ray Tracing)
// =============================================================================

/// Sizes needed to allocate acceleration structures and scratch buffers
pub const AccelerationStructureSizes = struct {
    acceleration_structure_size: u64,
    build_scratch_buffer_size: u64,
    refit_scratch_buffer_size: u64,
};

/// Built acceleration structure (can be BLAS or TLAS)
pub const AccelerationStructure = struct {
    handle: mtl.MTLAccelerationStructureRef,

    pub fn size(self: AccelerationStructure) u64 {
        return mtl.MTLAccelerationStructureSize(self.handle);
    }
};

/// Triangle geometry descriptor for building BLAS
pub const TriangleGeometryDescriptor = struct {
    handle: mtl.MTLAccelerationStructureTriangleGeometryDescriptorRef,

    pub fn init() TriangleGeometryDescriptor {
        return .{
            .handle = mtl.MTLAccelerationStructureTriangleGeometryDescriptorCreate(),
        };
    }

    pub fn setVertexBuffer(self: TriangleGeometryDescriptor, buffer: anytype, opts: struct { offset: u64 = 0, stride: u64 = 12 }) TriangleGeometryDescriptor {
        const buf_handle = if (@hasField(@TypeOf(buffer), "handle")) buffer.handle else buffer;
        mtl.MTLAccelerationStructureTriangleGeometryDescriptorSetVertexBuffer(self.handle, buf_handle);
        mtl.MTLAccelerationStructureTriangleGeometryDescriptorSetVertexBufferOffset(self.handle, opts.offset);
        mtl.MTLAccelerationStructureTriangleGeometryDescriptorSetVertexStride(self.handle, opts.stride);
        return self;
    }

    pub fn setIndexBuffer(self: TriangleGeometryDescriptor, buffer: anytype, index_type: IndexType, opts: struct { offset: u64 = 0 }) TriangleGeometryDescriptor {
        const buf_handle = if (@hasField(@TypeOf(buffer), "handle")) buffer.handle else buffer;
        mtl.MTLAccelerationStructureTriangleGeometryDescriptorSetIndexBuffer(self.handle, buf_handle);
        mtl.MTLAccelerationStructureTriangleGeometryDescriptorSetIndexBufferOffset(self.handle, opts.offset);
        mtl.MTLAccelerationStructureTriangleGeometryDescriptorSetIndexType(self.handle, @intFromEnum(index_type));
        return self;
    }

    pub fn setTriangleCount(self: TriangleGeometryDescriptor, count: u64) TriangleGeometryDescriptor {
        mtl.MTLAccelerationStructureTriangleGeometryDescriptorSetTriangleCount(self.handle, count);
        return self;
    }
};

/// Bounding box geometry descriptor for custom primitives (spheres, etc.)
pub const BoundingBoxGeometryDescriptor = struct {
    handle: mtl.MTLAccelerationStructureBoundingBoxGeometryDescriptorRef,

    pub fn init() BoundingBoxGeometryDescriptor {
        return .{
            .handle = mtl.MTLAccelerationStructureBoundingBoxGeometryDescriptorCreate(),
        };
    }

    pub fn setBoundingBoxBuffer(self: BoundingBoxGeometryDescriptor, buffer: anytype, opts: struct { offset: u64 = 0, stride: u64 = 24 }) BoundingBoxGeometryDescriptor {
        const buf_handle = if (@hasField(@TypeOf(buffer), "handle")) buffer.handle else buffer;
        mtl.MTLAccelerationStructureBoundingBoxGeometryDescriptorSetBoundingBoxBuffer(self.handle, buf_handle);
        mtl.MTLAccelerationStructureBoundingBoxGeometryDescriptorSetBoundingBoxBufferOffset(self.handle, opts.offset);
        mtl.MTLAccelerationStructureBoundingBoxGeometryDescriptorSetBoundingBoxStride(self.handle, opts.stride);
        return self;
    }

    pub fn setBoundingBoxCount(self: BoundingBoxGeometryDescriptor, count: u64) BoundingBoxGeometryDescriptor {
        mtl.MTLAccelerationStructureBoundingBoxGeometryDescriptorSetBoundingBoxCount(self.handle, count);
        return self;
    }
};

/// Primitive acceleration structure descriptor (BLAS - Bottom Level)
pub const PrimitiveAccelerationStructureDescriptor = struct {
    handle: mtl.MTLPrimitiveAccelerationStructureDescriptorRef,
    geometry_handles: [MAX_GEOMETRIES]*anyopaque = undefined,
    geometry_count: usize = 0,

    const MAX_GEOMETRIES = 16;

    pub fn init() PrimitiveAccelerationStructureDescriptor {
        return .{
            .handle = mtl.MTLPrimitiveAccelerationStructureDescriptorCreate(),
        };
    }

    /// Add a geometry descriptor (triangle or bounding box)
    pub fn addGeometry(self: *PrimitiveAccelerationStructureDescriptor, geometry: anytype) void {
        if (self.geometry_count < MAX_GEOMETRIES) {
            const geo_handle = if (@hasField(@TypeOf(geometry), "handle")) geometry.handle else geometry;
            self.geometry_handles[self.geometry_count] = geo_handle.?;
            self.geometry_count += 1;
        }
    }

    /// Finalize the descriptor (call after adding all geometries)
    pub fn build(self: *PrimitiveAccelerationStructureDescriptor) void {
        if (self.geometry_count > 0) {
            mtl.MTLPrimitiveAccelerationStructureDescriptorSetGeometryDescriptors(
                self.handle,
                @ptrCast(&self.geometry_handles),
                self.geometry_count,
            );
        }
    }
};

/// Instance acceleration structure descriptor (TLAS - Top Level)
pub const InstanceAccelerationStructureDescriptor = struct {
    handle: mtl.MTLInstanceAccelerationStructureDescriptorRef,
    blas_handles: [MAX_INSTANCES]mtl.MTLAccelerationStructureRef = undefined,
    blas_count: usize = 0,

    const MAX_INSTANCES = 64;

    pub fn init() InstanceAccelerationStructureDescriptor {
        return .{
            .handle = mtl.MTLInstanceAccelerationStructureDescriptorCreate(),
        };
    }

    /// Set the instance descriptor buffer (contains MTLAccelerationStructureInstanceDescriptor structs)
    pub fn setInstanceDescriptorBuffer(self: InstanceAccelerationStructureDescriptor, buffer: anytype, opts: struct { offset: u64 = 0, stride: u64 = 64 }) InstanceAccelerationStructureDescriptor {
        const buf_handle = if (@hasField(@TypeOf(buffer), "handle")) buffer.handle else buffer;
        mtl.MTLInstanceAccelerationStructureDescriptorSetInstanceDescriptorBuffer(self.handle, buf_handle);
        mtl.MTLInstanceAccelerationStructureDescriptorSetInstanceDescriptorBufferOffset(self.handle, opts.offset);
        mtl.MTLInstanceAccelerationStructureDescriptorSetInstanceDescriptorStride(self.handle, opts.stride);
        return self;
    }

    pub fn setInstanceCount(self: InstanceAccelerationStructureDescriptor, count: u64) InstanceAccelerationStructureDescriptor {
        mtl.MTLInstanceAccelerationStructureDescriptorSetInstanceCount(self.handle, count);
        return self;
    }

    /// Add a BLAS that instances can reference
    pub fn addInstancedAccelerationStructure(self: *InstanceAccelerationStructureDescriptor, accel: AccelerationStructure) void {
        if (self.blas_count < MAX_INSTANCES) {
            self.blas_handles[self.blas_count] = accel.handle;
            self.blas_count += 1;
        }
    }

    /// Finalize the descriptor (call after adding all BLAS references)
    pub fn build(self: *InstanceAccelerationStructureDescriptor) void {
        if (self.blas_count > 0) {
            mtl.MTLInstanceAccelerationStructureDescriptorSetInstancedAccelerationStructures(
                self.handle,
                @ptrCast(&self.blas_handles),
                self.blas_count,
            );
        }
    }
};

pub const IndexType = enum(u32) {
    uint16 = 0,
    uint32 = 1,
};

/// Scope for memory barriers - what resources to synchronize
pub const BarrierScope = enum(u32) {
    buffers = 1,
    textures = 2,
    render_targets = 4,

    pub fn all() u32 {
        return 1 | 2; // buffers | textures (render_targets not used in compute)
    }
};

/// Storage mode for buffers
pub const StorageMode = enum(u64) {
    /// CPU and GPU can both access. Default for Apple Silicon.
    shared = 0,
    /// macOS only: CPU/GPU access with explicit sync. Use didModifyRange().
    managed = 1,
    /// GPU only. Best performance for scratch/intermediate data.
    private = 2,

    fn toResourceOptions(self: StorageMode) u64 {
        return @intFromEnum(self) << 4; // MTLResourceStorageModeShift = 4
    }
};

// =============================================================================
// Textures
// =============================================================================

pub const PixelFormat = enum(u32) {
    rgba8unorm = 70,
    rgba8unorm_srgb = 71,
    rgba8snorm = 72,
    rgba8uint = 73,
    rgba8sint = 74,
    bgra8unorm = 80,
    bgra8unorm_srgb = 81,
    rgba16float = 115,
    rgba32float = 125,
    r8unorm = 10,
    r16float = 25,
    r32float = 55,
    rg8unorm = 30,
    rg16float = 65,
    rg32float = 105,
};

pub const TextureUsage = struct {
    pub const read: u32 = 1;
    pub const write: u32 = 2;
    pub const read_write: u32 = 3;
};

pub const Texture = struct {
    handle: mtl.MTLTextureRef,
    width: u64,
    height: u64,
    pixel_format: PixelFormat,

    /// Replace a region of the texture with pixel data.
    /// For 2D textures: region is { x, y, width, height }, slice = 0.
    /// Data should be tightly packed RGBA bytes (for rgba8unorm).
    pub fn replaceRegion(self: Texture, data: []const u8, region: struct {
        x: u64 = 0,
        y: u64 = 0,
        width: u64,
        height: u64,
    }) void {
        const bytes_per_pixel = self.bytesPerPixel();
        const bytes_per_row = region.width * bytes_per_pixel;

        mtl.MTLTextureReplaceRegion(
            self.handle,
            mtl.MTLRegion{
                .origin = .{ .x = region.x, .y = region.y, .z = 0 },
                .size = .{ .width = region.width, .height = region.height, .depth = 1 },
            },
            0, // mip level
            0, // slice
            data.ptr,
            bytes_per_row,
            0, // bytes per image (for 3D textures)
        );
    }

    /// Read pixels back from texture into a buffer.
    /// Buffer must be large enough: width * height * bytesPerPixel()
    pub fn getBytes(self: Texture, data: []u8, region: struct {
        x: u64 = 0,
        y: u64 = 0,
        width: u64,
        height: u64,
    }) void {
        const bytes_per_pixel = self.bytesPerPixel();
        const bytes_per_row = region.width * bytes_per_pixel;

        mtl.MTLTextureGetBytes(
            self.handle,
            data.ptr,
            bytes_per_row,
            0, // bytes per image
            mtl.MTLRegion{
                .origin = .{ .x = region.x, .y = region.y, .z = 0 },
                .size = .{ .width = region.width, .height = region.height, .depth = 1 },
            },
            0, // mip level
            0, // slice
        );
    }

    /// Convenience: replace entire texture
    pub fn upload(self: Texture, data: []const u8) void {
        self.replaceRegion(data, .{ .width = self.width, .height = self.height });
    }

    /// Convenience: read entire texture
    pub fn download(self: Texture, data: []u8) void {
        self.getBytes(data, .{ .width = self.width, .height = self.height });
    }

    fn bytesPerPixel(self: Texture) u64 {
        return switch (self.pixel_format) {
            .r8unorm => 1,
            .rg8unorm => 2,
            .rgba8unorm, .rgba8unorm_srgb, .rgba8snorm, .rgba8uint, .rgba8sint, .bgra8unorm, .bgra8unorm_srgb => 4,
            .r16float => 2,
            .rg16float => 4,
            .rgba16float => 8,
            .r32float => 4,
            .rg32float => 8,
            .rgba32float => 16,
        };
    }

    /// Save texture as PPM image file (for debugging/visualization)
    /// Assumes RGBA8 format, ignores alpha channel
    pub fn savePPM(self: Texture, path: []const u8, pixels: []const u8) !void {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        // PPM header: P6 format (binary RGB)
        var header_buf: [64]u8 = undefined;
        const header = std.fmt.bufPrint(&header_buf, "P6\n{d} {d}\n255\n", .{ self.width, self.height }) catch unreachable;
        try file.writeAll(header);

        // Write RGB pixels (skip alpha)
        var i: usize = 0;
        while (i < pixels.len) : (i += 4) {
            try file.writeAll(pixels[i..][0..3]); // R, G, B only
        }
    }
};

// =============================================================================
// Builder Pattern Command API
// =============================================================================

/// Encoder type currently active
const EncoderType = enum {
    none,
    compute,
    blit,
    acceleration_structure,
};

/// Max bytes that can be passed via setBytes (Metal limit is 4KB)
const MAX_BYTES_PER_SET = 256;

/// Recorded encoder operation for deferred execution
const EncoderOp = union(enum) {
    set_pipeline: mtl.MTLComputePipelineStateRef,
    set_buffer: struct { handle: mtl.MTLBufferRef, offset: u64, index: u64 },
    set_bytes: struct { data: [MAX_BYTES_PER_SET]u8, len: usize, index: u64 },
    set_texture: struct { handle: mtl.MTLTextureRef, index: u64 },
    set_acceleration_structure: struct { handle: mtl.MTLAccelerationStructureRef, index: u64 },
    dispatch: struct { grid: Size, threads: Size },
    dispatch_indirect: struct { buffer: mtl.MTLBufferRef, offset: u64, threads: Size },
    memory_barrier: BarrierScope,
    copy: struct { src: mtl.MTLBufferRef, src_offset: u64, dst: mtl.MTLBufferRef, dst_offset: u64, size: u64 },
    fill: struct { buffer: mtl.MTLBufferRef, offset: u64, size: u64, value: u8 },
    switch_to_blit: void,
    switch_to_compute: bool, // true = concurrent, false = serial
    switch_to_accel: void,
    build_accel: struct { accel: mtl.MTLAccelerationStructureRef, descriptor: mtl.MTLAccelerationStructureDescriptorRef, scratch: mtl.MTLBufferRef, scratch_offset: u64 },
    refit_accel: struct { source: mtl.MTLAccelerationStructureRef, descriptor: mtl.MTLAccelerationStructureDescriptorRef, dest: mtl.MTLAccelerationStructureRef, scratch: mtl.MTLBufferRef, scratch_offset: u64 },
    copy_accel: struct { source: mtl.MTLAccelerationStructureRef, dest: mtl.MTLAccelerationStructureRef },
    compact_accel: struct { source: mtl.MTLAccelerationStructureRef, dest: mtl.MTLAccelerationStructureRef },
    signal_event: struct { event: mtl.MTLEventRef, value: u64 },
    wait_event: struct { event: mtl.MTLEventRef, value: u64 },
};

const MAX_OPS = 256;

/// Command buffer builder - fluent API for recording GPU commands
/// Supports multiple encoder types in a single command buffer
///
/// Usage:
///   device.submit(&.{
///       Command.init()
///           .compute(pipeline, .{})              // serial (default)
///           .setBuffer(buf, 0, .{})
///           .dispatch1d(pipeline, count)
///           .compute(pipeline, .{ .concurrent = true })  // concurrent (needs barriers)
///           .dispatch1d(pipeline, count)
///           .barrier(.buffers)
///           .dispatch1d(pipeline, count)
///   });
pub const Command = struct {
    ops: [MAX_OPS]EncoderOp = undefined,
    op_count: usize = 0,

    /// Create a new command builder
    pub fn init() Command {
        return .{};
    }

    fn addOp(self: Command, op: EncoderOp) Command {
        var cmd = self;
        if (cmd.op_count < MAX_OPS) {
            cmd.ops[cmd.op_count] = op;
            cmd.op_count += 1;
        }
        return cmd;
    }

    /// Start or continue a compute encoder, setting the pipeline
    /// Options:
    ///   .concurrent = true  - dispatches can overlap, requires manual barriers
    ///   .concurrent = false - dispatches execute sequentially (default)
    pub fn compute(self: Command, pipeline: ComputePipeline, opts: struct { concurrent: bool = false }) Command {
        return self
            .addOp(.{ .switch_to_compute = opts.concurrent })
            .addOp(.{ .set_pipeline = pipeline.handle });
    }

    /// Set a buffer at the given index (compute encoder)
    pub fn setBuffer(self: Command, buffer: anytype, index: u64, opts: struct { offset: u64 = 0 }) Command {
        const handle = if (@hasField(@TypeOf(buffer), "handle")) buffer.handle else buffer;
        return self.addOp(.{ .set_buffer = .{ .handle = handle, .offset = opts.offset, .index = index } });
    }

    /// Set a texture at the given index (compute encoder)
    pub fn setTexture(self: Command, texture: Texture, index: u64) Command {
        return self.addOp(.{ .set_texture = .{ .handle = texture.handle, .index = index } });
    }

    /// Set inline bytes at the given index (compute encoder)
    /// Use for small data like uniforms, constants. Max 4KB, but keep small (<256 bytes).
    /// Data is copied immediately, so the source doesn't need to persist.
    pub fn setBytes(self: Command, data: anytype, index: u64) Command {
        const T = @TypeOf(data);
        const bytes = if (@typeInfo(T) == .pointer)
            std.mem.asBytes(data)
        else
            std.mem.asBytes(&data);

        if (bytes.len > MAX_BYTES_PER_SET) {
            @panic("setBytes data exceeds MAX_BYTES_PER_SET limit");
        }

        var op_data: [MAX_BYTES_PER_SET]u8 = undefined;
        @memcpy(op_data[0..bytes.len], bytes);

        return self.addOp(.{ .set_bytes = .{ .data = op_data, .len = bytes.len, .index = index } });
    }

    /// Dispatch compute threads
    pub fn dispatch(self: Command, grid: Size, threads_per_group: Size) Command {
        return self.addOp(.{ .dispatch = .{ .grid = grid, .threads = threads_per_group } });
    }

    /// Dispatch 1D compute - auto-calculates optimal grid/threads for element count
    pub fn dispatch1d(self: Command, pipeline: ComputePipeline, element_count: usize) Command {
        const grid, const threads = pipeline.gridFor1d(element_count);
        return self.dispatch(grid, threads);
    }

    /// Dispatch 2D compute for image processing - covers width x height pixels
    /// Uses 16x16 threadgroups (common for image kernels)
    pub fn dispatch2d(self: Command, width: u64, height: u64) Command {
        const threads_per_group = Size{ .width = 16, .height = 16 };
        const grid = Size{
            .width = (width + 15) / 16,
            .height = (height + 15) / 16,
        };
        return self.dispatch(grid, threads_per_group);
    }

    /// Insert a memory barrier (compute encoder)
    /// For serial dispatch (default): NOT needed - dispatches already execute in order.
    /// For concurrent dispatch: Required to ensure writes are visible to subsequent reads.
    /// Also useful for texture memory coherency.
    pub fn barrier(self: Command, scope: BarrierScope) Command {
        return self.addOp(.{ .memory_barrier = scope });
    }

    /// Start a blit encoder
    pub fn blit(self: Command) Command {
        return self.addOp(.switch_to_blit);
    }

    /// Copy buffer to buffer (blit encoder)
    pub fn copy(self: Command, src: anytype, dst: anytype, size: u64, opts: struct { src_offset: u64 = 0, dst_offset: u64 = 0 }) Command {
        const src_handle = if (@hasField(@TypeOf(src), "handle")) src.handle else src;
        const dst_handle = if (@hasField(@TypeOf(dst), "handle")) dst.handle else dst;
        return self.addOp(.{ .copy = .{ .src = src_handle, .src_offset = opts.src_offset, .dst = dst_handle, .dst_offset = opts.dst_offset, .size = size } });
    }

    /// Fill buffer with a value (blit encoder)
    pub fn fill(self: Command, buffer: anytype, value: u8, size: u64, opts: struct { offset: u64 = 0 }) Command {
        const handle = if (@hasField(@TypeOf(buffer), "handle")) buffer.handle else buffer;
        return self.addOp(.{ .fill = .{ .buffer = handle, .offset = opts.offset, .size = size, .value = value } });
    }

    // =========================================================================
    // Acceleration Structure Commands
    // =========================================================================

    /// Start an acceleration structure encoder
    pub fn accel(self: Command) Command {
        return self.addOp(.switch_to_accel);
    }

    /// Build an acceleration structure (requires accel encoder)
    pub fn buildAccelerationStructure(
        self: Command,
        acceleration_structure: AccelerationStructure,
        descriptor: anytype,
        scratch_buffer: anytype,
        opts: struct { scratch_offset: u64 = 0 },
    ) Command {
        const desc_handle = if (@hasField(@TypeOf(descriptor), "handle")) descriptor.handle else descriptor;
        const scratch_handle = if (@hasField(@TypeOf(scratch_buffer), "handle")) scratch_buffer.handle else scratch_buffer;
        return self.addOp(.{ .build_accel = .{
            .accel = acceleration_structure.handle,
            .descriptor = desc_handle,
            .scratch = scratch_handle,
            .scratch_offset = opts.scratch_offset,
        } });
    }

    /// Refit an acceleration structure (for dynamic geometry updates)
    pub fn refitAccelerationStructure(
        self: Command,
        source: AccelerationStructure,
        descriptor: anytype,
        dest: AccelerationStructure,
        scratch_buffer: anytype,
        opts: struct { scratch_offset: u64 = 0 },
    ) Command {
        const desc_handle = if (@hasField(@TypeOf(descriptor), "handle")) descriptor.handle else descriptor;
        const scratch_handle = if (@hasField(@TypeOf(scratch_buffer), "handle")) scratch_buffer.handle else scratch_buffer;
        return self.addOp(.{ .refit_accel = .{
            .source = source.handle,
            .descriptor = desc_handle,
            .dest = dest.handle,
            .scratch = scratch_handle,
            .scratch_offset = opts.scratch_offset,
        } });
    }

    /// Copy an acceleration structure
    pub fn copyAccelerationStructure(self: Command, source: AccelerationStructure, dest: AccelerationStructure) Command {
        return self.addOp(.{ .copy_accel = .{ .source = source.handle, .dest = dest.handle } });
    }

    /// Copy and compact an acceleration structure (reduces memory after build)
    pub fn compactAccelerationStructure(self: Command, source: AccelerationStructure, dest: AccelerationStructure) Command {
        return self.addOp(.{ .compact_accel = .{ .source = source.handle, .dest = dest.handle } });
    }

    /// Set an acceleration structure for use in compute shader (for ray tracing)
    pub fn setAccelerationStructure(self: Command, accel_struct: AccelerationStructure, index: u64) Command {
        return self.addOp(.{ .set_acceleration_structure = .{ .handle = accel_struct.handle, .index = index } });
    }

    // =========================================================================
    // Synchronization
    // =========================================================================

    /// Signal an event with a value (encoded at command buffer level)
    /// Another command buffer can wait on this event+value.
    pub fn signalEvent(self: Command, event: anytype, value: u64) Command {
        const handle = if (@hasField(@TypeOf(event), "handle")) event.handle else event;
        return self.addOp(.{ .signal_event = .{ .event = handle, .value = value } });
    }

    /// Wait for an event to reach a value before continuing
    pub fn waitEvent(self: Command, event: anytype, value: u64) Command {
        const handle = if (@hasField(@TypeOf(event), "handle")) event.handle else event;
        return self.addOp(.{ .wait_event = .{ .event = handle, .value = value } });
    }

    /// Finalize and execute the command (called by Device.submit)
    /// Returns the command buffer for waiting
    fn finalize(self: *Command, queue: mtl.MTLCommandQueueRef) mtl.MTLCommandBufferRef {
        const cmd_buf = mtl.MTLCommandQueueCommandBuffer(queue) orelse @panic("Failed to create command buffer");

        var current_encoder: ?*anyopaque = null;
        var encoder_type: EncoderType = .none;

        // Helper to end current encoder
        const endEncoder = struct {
            fn end(enc: ?*anyopaque, enc_type: EncoderType) void {
                if (enc) |e| {
                    switch (enc_type) {
                        .compute => mtl.MTLComputeCommandEncoderEndEncoding(@ptrCast(e)),
                        .blit => mtl.MTLBlitCommandEncoderEndEncoding(@ptrCast(e)),
                        .acceleration_structure => mtl.MTLAccelerationStructureCommandEncoderEndEncoding(@ptrCast(e)),
                        .none => {},
                    }
                }
            }
        }.end;

        for (self.ops[0..self.op_count]) |op| {
            switch (op) {
                .switch_to_compute => |concurrent| {
                    if (encoder_type != .compute) {
                        endEncoder(current_encoder, encoder_type);
                        if (concurrent) {
                            current_encoder = mtl.MTLCommandBufferComputeCommandEncoderWithDispatchType(cmd_buf, mtl.MTLDispatchTypeConcurrent) orelse @panic("Failed to create concurrent compute encoder");
                        } else {
                            current_encoder = mtl.MTLCommandBufferComputeCommandEncoder(cmd_buf) orelse @panic("Failed to create compute encoder");
                        }
                        encoder_type = .compute;
                    }
                },
                .switch_to_blit => {
                    if (encoder_type != .blit) {
                        endEncoder(current_encoder, encoder_type);
                        current_encoder = mtl.MTLCommandBufferBlitCommandEncoder(cmd_buf) orelse @panic("Failed to create blit encoder");
                        encoder_type = .blit;
                    }
                },
                .switch_to_accel => {
                    if (encoder_type != .acceleration_structure) {
                        endEncoder(current_encoder, encoder_type);
                        current_encoder = mtl.MTLCommandBufferAccelerationStructureCommandEncoder(cmd_buf) orelse @panic("Failed to create acceleration structure encoder");
                        encoder_type = .acceleration_structure;
                    }
                },
                .set_pipeline => |pipeline_handle| {
                    if (encoder_type == .compute) {
                        mtl.MTLComputeCommandEncoderSetComputePipelineState(@ptrCast(current_encoder.?), pipeline_handle);
                    }
                },
                .set_buffer => |b| {
                    if (encoder_type == .compute) {
                        mtl.MTLComputeCommandEncoderSetBuffer(@ptrCast(current_encoder.?), b.handle, b.offset, b.index);
                    }
                },
                .set_bytes => |b| {
                    if (encoder_type == .compute) {
                        mtl.MTLComputeCommandEncoderSetBytes(@ptrCast(current_encoder.?), &b.data, b.len, b.index);
                    }
                },
                .set_texture => |t| {
                    if (encoder_type == .compute) {
                        mtl.MTLComputeCommandEncoderSetTexture(@ptrCast(current_encoder.?), t.handle, t.index);
                    }
                },
                .set_acceleration_structure => |a| {
                    if (encoder_type == .compute) {
                        mtl.MTLComputeCommandEncoderSetAccelerationStructure(@ptrCast(current_encoder.?), a.handle, a.index);
                    }
                },
                .dispatch => |d| {
                    if (encoder_type == .compute) {
                        mtl.MTLComputeCommandEncoderDispatchThreadgroups(
                            @ptrCast(current_encoder.?),
                            mtl.MTLSize{ .width = d.grid.width, .height = d.grid.height, .depth = d.grid.depth },
                            mtl.MTLSize{ .width = d.threads.width, .height = d.threads.height, .depth = d.threads.depth },
                        );
                    }
                },
                .copy => |c| {
                    if (encoder_type == .blit) {
                        mtl.MTLBlitCommandEncoderCopyFromBuffer(@ptrCast(current_encoder.?), c.src, c.src_offset, c.dst, c.dst_offset, c.size);
                    }
                },
                .fill => |f| {
                    if (encoder_type == .blit) {
                        mtl.MTLBlitCommandEncoderFillBuffer(@ptrCast(current_encoder.?), f.buffer, f.offset, f.size, f.value);
                    }
                },
                .build_accel => |b| {
                    if (encoder_type == .acceleration_structure) {
                        mtl.MTLAccelerationStructureCommandEncoderBuildAccelerationStructure(
                            @ptrCast(current_encoder.?),
                            b.accel,
                            b.descriptor,
                            b.scratch,
                            b.scratch_offset,
                        );
                    }
                },
                .refit_accel => |r| {
                    if (encoder_type == .acceleration_structure) {
                        mtl.MTLAccelerationStructureCommandEncoderRefitAccelerationStructure(
                            @ptrCast(current_encoder.?),
                            r.source,
                            r.descriptor,
                            r.dest,
                            r.scratch,
                            r.scratch_offset,
                        );
                    }
                },
                .copy_accel => |c| {
                    if (encoder_type == .acceleration_structure) {
                        mtl.MTLAccelerationStructureCommandEncoderCopyAccelerationStructure(
                            @ptrCast(current_encoder.?),
                            c.source,
                            c.dest,
                        );
                    }
                },
                .compact_accel => |c| {
                    if (encoder_type == .acceleration_structure) {
                        mtl.MTLAccelerationStructureCommandEncoderCopyAndCompactAccelerationStructure(
                            @ptrCast(current_encoder.?),
                            c.source,
                            c.dest,
                        );
                    }
                },
                .memory_barrier => |scope| {
                    if (encoder_type == .compute) {
                        mtl.MTLComputeCommandEncoderMemoryBarrierWithScope(@ptrCast(current_encoder.?), @intFromEnum(scope));
                    }
                },
                .signal_event => |e| {
                    // Events are encoded on command buffer, need to end current encoder first
                    endEncoder(current_encoder, encoder_type);
                    current_encoder = null;
                    encoder_type = .none;
                    mtl.MTLCommandBufferEncodeSignalEvent(cmd_buf, e.event, e.value);
                },
                .wait_event => |e| {
                    // Events are encoded on command buffer, need to end current encoder first
                    endEncoder(current_encoder, encoder_type);
                    current_encoder = null;
                    encoder_type = .none;
                    mtl.MTLCommandBufferEncodeWaitForEvent(cmd_buf, e.event, e.value);
                },
                // Not yet implemented
                .dispatch_indirect => {},
            }
        }

        // End final encoder
        endEncoder(current_encoder, encoder_type);

        mtl.MTLCommandBufferCommit(cmd_buf);
        return cmd_buf;
    }
};

/// Fence for async submission - call wait() to block until complete
pub const Fence = struct {
    command_buffer: ?mtl.MTLCommandBufferRef,

    pub fn wait(self: Fence) void {
        if (self.command_buffer) |buf| {
            mtl.MTLCommandBufferWaitUntilCompleted(buf);
        }
    }
};

/// Event for GPU-GPU synchronization across command buffers
/// Use to coordinate work between different submissions or queues.
pub const Event = struct {
    handle: mtl.MTLEventRef,

    pub fn init(device: Device) Event {
        return .{ .handle = mtl.MTLDeviceNewEvent(device.handle) };
    }
};

/// SharedEvent extends Event with CPU-GPU synchronization
/// Can also synchronize across processes.
pub const SharedEvent = struct {
    handle: mtl.MTLSharedEventRef,

    pub fn init(device: Device) SharedEvent {
        return .{ .handle = mtl.MTLDeviceNewSharedEvent(device.handle) };
    }

    /// Get current signaled value (can be read from CPU)
    pub fn signaledValue(self: SharedEvent) u64 {
        return mtl.MTLSharedEventSignaledValue(self.handle);
    }

    /// Set signaled value from CPU (allows CPU to signal GPU)
    pub fn setSignaledValue(self: SharedEvent, value: u64) void {
        mtl.MTLSharedEventSetSignaledValue(self.handle, value);
    }
};
