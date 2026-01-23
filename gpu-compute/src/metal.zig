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

    /// Submit a command, wait for completion
    pub fn submit(self: *Device, command: anytype) void {
        const queue = self.nextQueue();
        const cmd_buf = command.finalize(queue);
        mtl.MTLCommandBufferWaitUntilCompleted(cmd_buf);
    }

    /// Submit a command, return fence for async waiting
    pub fn submitAsync(self: *Device, command: anytype) Fence {
        const queue = self.nextQueue();
        const cmd_buf = command.finalize(queue);
        return Fence{ .command_buffer = cmd_buf };
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
// Comptime Command Builder API
// =============================================================================

/// Operation types for comptime command building
const Op = enum {
    switch_to_compute_serial,
    switch_to_compute_concurrent,
    switch_to_blit,
    switch_to_accel,
    set_pipeline,
    set_buffer,
    set_bytes,
    set_texture,
    set_accel_struct,
    dispatch,
    dispatch_2d,
    barrier,
    copy,
    fill,
    build_accel,
    refit_accel,
    copy_accel,
    compact_accel,
    signal_event,
    wait_event,
};

/// Comptime command builder - generates optimal code at compile time
/// Each method returns a new type with the operation appended.
///
/// Usage:
///   device.submit(
///       cmd.compute(pipeline, .{})
///          .setBuffer(buf_a, 0, .{})
///          .setBuffer(buf_b, 1, .{})
///          .dispatch(grid, threads)
///   );
pub fn Command(comptime ops: []const Op) type {
    return struct {
        // Runtime data stored per-operation
        data: Data,

        const Self = @This();
        const ops_list = ops;

        /// Runtime data structure - holds handles/values for each op
        const Data = GenerateDataStruct(ops);

        pub fn init() Self {
            return .{ .data = undefined };
        }

        /// Copy data fields from self to result by iterating over ops (comptime-known)
        fn copyDataTo(self: *const Self, comptime ResultType: type, result: *ResultType) void {
            inline for (ops, 0..) |op, i| {
                switch (op) {
                    .set_pipeline => @field(result.data, pipelineFieldName(i)) = @field(self.data, pipelineFieldName(i)),
                    .set_buffer => @field(result.data, bufferFieldName(i)) = @field(self.data, bufferFieldName(i)),
                    .set_texture => @field(result.data, textureFieldName(i)) = @field(self.data, textureFieldName(i)),
                    .set_bytes => @field(result.data, bytesFieldName(i)) = @field(self.data, bytesFieldName(i)),
                    .set_accel_struct => @field(result.data, accelStructFieldName(i)) = @field(self.data, accelStructFieldName(i)),
                    .dispatch => @field(result.data, dispatchFieldName(i)) = @field(self.data, dispatchFieldName(i)),
                    .dispatch_2d => @field(result.data, dispatch2dFieldName(i)) = @field(self.data, dispatch2dFieldName(i)),
                    .barrier => @field(result.data, barrierFieldName(i)) = @field(self.data, barrierFieldName(i)),
                    .copy => @field(result.data, copyFieldName(i)) = @field(self.data, copyFieldName(i)),
                    .fill => @field(result.data, fillFieldName(i)) = @field(self.data, fillFieldName(i)),
                    .build_accel => @field(result.data, buildAccelFieldName(i)) = @field(self.data, buildAccelFieldName(i)),
                    // Ops without runtime data
                    .switch_to_compute_serial, .switch_to_compute_concurrent, .switch_to_blit, .switch_to_accel, .refit_accel, .copy_accel, .compact_accel, .signal_event, .wait_event => {},
                }
            }
        }

        // =====================================================================
        // Compute Operations
        // =====================================================================

        /// Start a serial compute encoder (dispatches execute sequentially)
        pub fn compute(self: Self, pipeline: ComputePipeline) Command(ops ++ &[_]Op{ .switch_to_compute_serial, .set_pipeline }) {
            var result: Command(ops ++ &[_]Op{ .switch_to_compute_serial, .set_pipeline }) = .{ .data = undefined };
            self.copyDataTo(@TypeOf(result), &result);
            @field(result.data, pipelineFieldName(ops.len + 1)) = pipeline.handle;
            return result;
        }

        /// Start a concurrent compute encoder (dispatches can overlap, needs barriers)
        pub fn computeConcurrent(self: Self, pipeline: ComputePipeline) Command(ops ++ &[_]Op{ .switch_to_compute_concurrent, .set_pipeline }) {
            var result: Command(ops ++ &[_]Op{ .switch_to_compute_concurrent, .set_pipeline }) = .{ .data = undefined };
            self.copyDataTo(@TypeOf(result), &result);
            @field(result.data, pipelineFieldName(ops.len + 1)) = pipeline.handle;
            return result;
        }

        pub fn setBuffer(self: Self, buffer: anytype, index: u64, opts: struct { offset: u64 = 0 }) Command(ops ++ &[_]Op{.set_buffer}) {
            const handle = if (@hasField(@TypeOf(buffer), "handle")) buffer.handle else buffer;
            var result: Command(ops ++ &[_]Op{.set_buffer}) = .{ .data = undefined };
            self.copyDataTo(@TypeOf(result), &result);
            @field(result.data, bufferFieldName(ops.len)) = .{ .handle = handle, .offset = opts.offset, .index = index };
            return result;
        }

        pub fn setTexture(self: Self, texture: Texture, index: u64) Command(ops ++ &[_]Op{.set_texture}) {
            var result: Command(ops ++ &[_]Op{.set_texture}) = .{ .data = undefined };
            self.copyDataTo(@TypeOf(result), &result);
            @field(result.data, textureFieldName(ops.len)) = .{ .handle = texture.handle, .index = index };
            return result;
        }

        pub fn setBytes(self: Self, data: anytype, index: u64) Command(ops ++ &[_]Op{.set_bytes}) {
            var result: Command(ops ++ &[_]Op{.set_bytes}) = .{ .data = undefined };
            self.copyDataTo(@TypeOf(result), &result);
            const T = @TypeOf(data);
            const bytes_ptr = if (@typeInfo(T) == .pointer) data else &data;
            @field(result.data, bytesFieldName(ops.len)) = .{ .ptr = @ptrCast(bytes_ptr), .len = @sizeOf(std.meta.Child(if (@typeInfo(T) == .pointer) T else *const T)), .index = index };
            return result;
        }

        pub fn dispatch(self: Self, grid: Size, threads_per_group: Size) Command(ops ++ &[_]Op{.dispatch}) {
            var result: Command(ops ++ &[_]Op{.dispatch}) = .{ .data = undefined };
            self.copyDataTo(@TypeOf(result), &result);
            @field(result.data, dispatchFieldName(ops.len)) = .{ .grid = grid, .threads = threads_per_group };
            return result;
        }

        pub fn dispatch2d(self: Self, width: u64, height: u64) Command(ops ++ &[_]Op{.dispatch_2d}) {
            var result: Command(ops ++ &[_]Op{.dispatch_2d}) = .{ .data = undefined };
            self.copyDataTo(@TypeOf(result), &result);
            @field(result.data, dispatch2dFieldName(ops.len)) = .{ .width = width, .height = height };
            return result;
        }

        pub fn dispatch1d(self: Self, pipeline: ComputePipeline, element_count: usize) Command(ops ++ &[_]Op{.dispatch}) {
            const grid, const threads = pipeline.gridFor1d(element_count);
            return self.dispatch(grid, threads);
        }

        pub fn barrier(self: Self, scope: BarrierScope) Command(ops ++ &[_]Op{.barrier}) {
            var result: Command(ops ++ &[_]Op{.barrier}) = .{ .data = undefined };
            self.copyDataTo(@TypeOf(result), &result);
            @field(result.data, barrierFieldName(ops.len)) = scope;
            return result;
        }

        // =====================================================================
        // Blit Operations
        // =====================================================================

        pub fn blit(self: Self) Command(ops ++ &[_]Op{.switch_to_blit}) {
            var result: Command(ops ++ &[_]Op{.switch_to_blit}) = .{ .data = undefined };
            self.copyDataTo(@TypeOf(result), &result);
            return result;
        }

        pub fn copy(self: Self, src: anytype, dst: anytype, size: u64, opts: struct { src_offset: u64 = 0, dst_offset: u64 = 0 }) Command(ops ++ &[_]Op{.copy}) {
            const src_handle = if (@hasField(@TypeOf(src), "handle")) src.handle else src;
            const dst_handle = if (@hasField(@TypeOf(dst), "handle")) dst.handle else dst;
            var result: Command(ops ++ &[_]Op{.copy}) = .{ .data = undefined };
            self.copyDataTo(@TypeOf(result), &result);
            @field(result.data, copyFieldName(ops.len)) = .{ .src = src_handle, .src_offset = opts.src_offset, .dst = dst_handle, .dst_offset = opts.dst_offset, .size = size };
            return result;
        }

        pub fn fill(self: Self, buffer: anytype, value: u8, size: u64, opts: struct { offset: u64 = 0 }) Command(ops ++ &[_]Op{.fill}) {
            const handle = if (@hasField(@TypeOf(buffer), "handle")) buffer.handle else buffer;
            var result: Command(ops ++ &[_]Op{.fill}) = .{ .data = undefined };
            self.copyDataTo(@TypeOf(result), &result);
            @field(result.data, fillFieldName(ops.len)) = .{ .buffer = handle, .offset = opts.offset, .size = size, .value = value };
            return result;
        }

        // =====================================================================
        // Acceleration Structure Operations
        // =====================================================================

        pub fn accel(self: Self) Command(ops ++ &[_]Op{.switch_to_accel}) {
            var result: Command(ops ++ &[_]Op{.switch_to_accel}) = .{ .data = undefined };
            self.copyDataTo(@TypeOf(result), &result);
            return result;
        }

        pub fn buildAccelerationStructure(
            self: Self,
            acceleration_structure: AccelerationStructure,
            descriptor: anytype,
            scratch_buffer: anytype,
            opts: struct { scratch_offset: u64 = 0 },
        ) Command(ops ++ &[_]Op{.build_accel}) {
            const desc_handle = if (@hasField(@TypeOf(descriptor), "handle")) descriptor.handle else descriptor;
            const scratch_handle = if (@hasField(@TypeOf(scratch_buffer), "handle")) scratch_buffer.handle else scratch_buffer;
            var result: Command(ops ++ &[_]Op{.build_accel}) = .{ .data = undefined };
            self.copyDataTo(@TypeOf(result), &result);
            @field(result.data, buildAccelFieldName(ops.len)) = .{
                .accel = acceleration_structure.handle,
                .descriptor = desc_handle,
                .scratch = scratch_handle,
                .scratch_offset = opts.scratch_offset,
            };
            return result;
        }

        pub fn setAccelerationStructure(self: Self, accel_struct: AccelerationStructure, index: u64) Command(ops ++ &[_]Op{.set_accel_struct}) {
            var result: Command(ops ++ &[_]Op{.set_accel_struct}) = .{ .data = undefined };
            self.copyDataTo(@TypeOf(result), &result);
            @field(result.data, accelStructFieldName(ops.len)) = .{ .handle = accel_struct.handle, .index = index };
            return result;
        }

        // =====================================================================
        // Finalize - generates inline Metal calls
        // =====================================================================

        pub inline fn finalize(self: *const Self, queue: mtl.MTLCommandQueueRef) mtl.MTLCommandBufferRef {
            const cmd_buf = mtl.MTLCommandQueueCommandBuffer(queue) orelse @panic("Failed to create command buffer");

            var compute_enc: ?mtl.MTLComputeCommandEncoderRef = null;
            var blit_enc: ?mtl.MTLBlitCommandEncoderRef = null;
            var accel_enc: ?mtl.MTLAccelerationStructureCommandEncoderRef = null;

            inline for (ops, 0..) |op, i| {
                switch (op) {
                    .switch_to_compute_serial => {
                        if (blit_enc) |e| {
                            mtl.MTLBlitCommandEncoderEndEncoding(e);
                            blit_enc = null;
                        }
                        if (accel_enc) |e| {
                            mtl.MTLAccelerationStructureCommandEncoderEndEncoding(e);
                            accel_enc = null;
                        }
                        if (compute_enc == null) {
                            compute_enc = mtl.MTLCommandBufferComputeCommandEncoder(cmd_buf);
                        }
                    },
                    .switch_to_compute_concurrent => {
                        if (blit_enc) |e| {
                            mtl.MTLBlitCommandEncoderEndEncoding(e);
                            blit_enc = null;
                        }
                        if (accel_enc) |e| {
                            mtl.MTLAccelerationStructureCommandEncoderEndEncoding(e);
                            accel_enc = null;
                        }
                        if (compute_enc == null) {
                            compute_enc = mtl.MTLCommandBufferComputeCommandEncoderWithDispatchType(cmd_buf, mtl.MTLDispatchTypeConcurrent);
                        }
                    },
                    .switch_to_blit => {
                        if (compute_enc) |e| {
                            mtl.MTLComputeCommandEncoderEndEncoding(e);
                            compute_enc = null;
                        }
                        if (accel_enc) |e| {
                            mtl.MTLAccelerationStructureCommandEncoderEndEncoding(e);
                            accel_enc = null;
                        }
                        if (blit_enc == null) {
                            blit_enc = mtl.MTLCommandBufferBlitCommandEncoder(cmd_buf);
                        }
                    },
                    .switch_to_accel => {
                        if (compute_enc) |e| {
                            mtl.MTLComputeCommandEncoderEndEncoding(e);
                            compute_enc = null;
                        }
                        if (blit_enc) |e| {
                            mtl.MTLBlitCommandEncoderEndEncoding(e);
                            blit_enc = null;
                        }
                        if (accel_enc == null) {
                            accel_enc = mtl.MTLCommandBufferAccelerationStructureCommandEncoder(cmd_buf);
                        }
                    },
                    .set_pipeline => {
                        const handle = @field(self.data, pipelineFieldName(i));
                        mtl.MTLComputeCommandEncoderSetComputePipelineState(compute_enc.?, handle);
                    },
                    .set_buffer => {
                        const d = @field(self.data, bufferFieldName(i));
                        mtl.MTLComputeCommandEncoderSetBuffer(compute_enc.?, d.handle, d.offset, d.index);
                    },
                    .set_texture => {
                        const d = @field(self.data, textureFieldName(i));
                        mtl.MTLComputeCommandEncoderSetTexture(compute_enc.?, d.handle, d.index);
                    },
                    .set_bytes => {
                        const d = @field(self.data, bytesFieldName(i));
                        mtl.MTLComputeCommandEncoderSetBytes(compute_enc.?, d.ptr, d.len, d.index);
                    },
                    .set_accel_struct => {
                        const d = @field(self.data, accelStructFieldName(i));
                        mtl.MTLComputeCommandEncoderSetAccelerationStructure(compute_enc.?, d.handle, d.index);
                    },
                    .dispatch => {
                        const d = @field(self.data, dispatchFieldName(i));
                        mtl.MTLComputeCommandEncoderDispatchThreadgroups(
                            compute_enc.?,
                            mtl.MTLSize{ .width = d.grid.width, .height = d.grid.height, .depth = d.grid.depth },
                            mtl.MTLSize{ .width = d.threads.width, .height = d.threads.height, .depth = d.threads.depth },
                        );
                    },
                    .dispatch_2d => {
                        const d = @field(self.data, dispatch2dFieldName(i));
                        const grid_w = (d.width + 15) / 16;
                        const grid_h = (d.height + 15) / 16;
                        mtl.MTLComputeCommandEncoderDispatchThreadgroups(
                            compute_enc.?,
                            mtl.MTLSize{ .width = grid_w, .height = grid_h, .depth = 1 },
                            mtl.MTLSize{ .width = 16, .height = 16, .depth = 1 },
                        );
                    },
                    .barrier => {
                        const scope = @field(self.data, barrierFieldName(i));
                        mtl.MTLComputeCommandEncoderMemoryBarrierWithScope(compute_enc.?, @intFromEnum(scope));
                    },
                    .copy => {
                        const d = @field(self.data, copyFieldName(i));
                        mtl.MTLBlitCommandEncoderCopyFromBuffer(blit_enc.?, d.src, d.src_offset, d.dst, d.dst_offset, d.size);
                    },
                    .fill => {
                        const d = @field(self.data, fillFieldName(i));
                        mtl.MTLBlitCommandEncoderFillBuffer(blit_enc.?, d.buffer, d.offset, d.size, d.value);
                    },
                    .build_accel => {
                        const d = @field(self.data, buildAccelFieldName(i));
                        mtl.MTLAccelerationStructureCommandEncoderBuildAccelerationStructure(accel_enc.?, d.accel, d.descriptor, d.scratch, d.scratch_offset);
                    },
                    .refit_accel, .copy_accel, .compact_accel, .signal_event, .wait_event => {
                        // TODO: implement these as needed
                    },
                }
            }

            // End active encoders
            if (compute_enc) |e| mtl.MTLComputeCommandEncoderEndEncoding(e);
            if (blit_enc) |e| mtl.MTLBlitCommandEncoderEndEncoding(e);
            if (accel_enc) |e| mtl.MTLAccelerationStructureCommandEncoderEndEncoding(e);

            mtl.MTLCommandBufferCommit(cmd_buf);
            return cmd_buf;
        }
    };
}

// Field name generators for unique field names per operation index
fn pipelineFieldName(comptime i: usize) [:0]const u8 {
    return std.fmt.comptimePrint("pipeline_{d}", .{i});
}
fn bufferFieldName(comptime i: usize) [:0]const u8 {
    return std.fmt.comptimePrint("buffer_{d}", .{i});
}
fn textureFieldName(comptime i: usize) [:0]const u8 {
    return std.fmt.comptimePrint("texture_{d}", .{i});
}
fn bytesFieldName(comptime i: usize) [:0]const u8 {
    return std.fmt.comptimePrint("bytes_{d}", .{i});
}
fn dispatchFieldName(comptime i: usize) [:0]const u8 {
    return std.fmt.comptimePrint("dispatch_{d}", .{i});
}
fn dispatch2dFieldName(comptime i: usize) [:0]const u8 {
    return std.fmt.comptimePrint("dispatch2d_{d}", .{i});
}
fn barrierFieldName(comptime i: usize) [:0]const u8 {
    return std.fmt.comptimePrint("barrier_{d}", .{i});
}
fn copyFieldName(comptime i: usize) [:0]const u8 {
    return std.fmt.comptimePrint("copy_{d}", .{i});
}
fn fillFieldName(comptime i: usize) [:0]const u8 {
    return std.fmt.comptimePrint("fill_{d}", .{i});
}
fn buildAccelFieldName(comptime i: usize) [:0]const u8 {
    return std.fmt.comptimePrint("build_accel_{d}", .{i});
}
fn accelStructFieldName(comptime i: usize) [:0]const u8 {
    return std.fmt.comptimePrint("accel_struct_{d}", .{i});
}

// Data types for each operation
const BufferData = struct { handle: mtl.MTLBufferRef, offset: u64, index: u64 };
const TextureData = struct { handle: mtl.MTLTextureRef, index: u64 };
const BytesData = struct { ptr: *const anyopaque, len: usize, index: u64 };
const AccelStructData = struct { handle: mtl.MTLAccelerationStructureRef, index: u64 };
const DispatchData = struct { grid: Size, threads: Size };
const Dispatch2dData = struct { width: u64, height: u64 };
const CopyData = struct { src: mtl.MTLBufferRef, src_offset: u64, dst: mtl.MTLBufferRef, dst_offset: u64, size: u64 };
const FillData = struct { buffer: mtl.MTLBufferRef, offset: u64, size: u64, value: u8 };
const BuildAccelData = struct { accel: mtl.MTLAccelerationStructureRef, descriptor: mtl.MTLAccelerationStructureDescriptorRef, scratch: mtl.MTLBufferRef, scratch_offset: u64 };

fn makeField(comptime name: [:0]const u8, comptime T: type) std.builtin.Type.StructField {
    return .{
        .name = name,
        .type = T,
        .default_value_ptr = null,
        .is_comptime = false,
        .alignment = @alignOf(T),
    };
}

/// Generate a struct type holding runtime data for the given ops
fn GenerateDataStruct(comptime ops: []const Op) type {
    var fields: []const std.builtin.Type.StructField = &.{};

    for (ops, 0..) |op, i| {
        const maybe_field: ?std.builtin.Type.StructField = switch (op) {
            .set_pipeline => makeField(pipelineFieldName(i), mtl.MTLComputePipelineStateRef),
            .set_buffer => makeField(bufferFieldName(i), BufferData),
            .set_texture => makeField(textureFieldName(i), TextureData),
            .set_bytes => makeField(bytesFieldName(i), BytesData),
            .set_accel_struct => makeField(accelStructFieldName(i), AccelStructData),
            .dispatch => makeField(dispatchFieldName(i), DispatchData),
            .dispatch_2d => makeField(dispatch2dFieldName(i), Dispatch2dData),
            .barrier => makeField(barrierFieldName(i), BarrierScope),
            .copy => makeField(copyFieldName(i), CopyData),
            .fill => makeField(fillFieldName(i), FillData),
            .build_accel => makeField(buildAccelFieldName(i), BuildAccelData),
            // Ops that don't need runtime data
            .switch_to_compute_serial, .switch_to_compute_concurrent, .switch_to_blit, .switch_to_accel, .refit_accel, .copy_accel, .compact_accel, .signal_event, .wait_event => null,
        };
        if (maybe_field) |field| {
            fields = fields ++ &[_]std.builtin.Type.StructField{field};
        }
    }

    return @Type(.{ .@"struct" = .{
        .layout = .auto,
        .fields = fields,
        .decls = &.{},
        .is_tuple = false,
    } });
}

/// Entry point - start building a command
pub const cmd = Command(&.{}).init();

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
