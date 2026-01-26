// metal.zig - Idiomatic Zig wrapper for Metal
//
// Design principles:
// - Less tedious than raw MTL*** APIs
// - Full Metal flexibility preserved
// - Scope-based encoder lifetime with defer
// - Convenience methods without losing control

const std = @import("std");
pub const mtl = @cImport({
    @cInclude("metal_wrapper.h");
});

// =============================================================================
// Errors
// =============================================================================

pub const Error = error{
    DeviceNotFound,
    CommandQueueCreationFailed,
    CommandBufferCreationFailed,
    LibraryCompilationFailed,
    FunctionNotFound,
    PipelineCreationFailed,
    BufferCreationFailed,
    TextureCreationFailed,
};

// =============================================================================
// Device - Resource Creation & Submission
// =============================================================================

pub const Device = struct {
    handle: mtl.MTLDeviceRef,
    queue: mtl.MTLCommandQueueRef,

    /// Create device with system default GPU
    pub fn create() Error!Device {
        const handle = mtl.MTLWrapperCreateSystemDefaultDevice() orelse
            return error.DeviceNotFound;
        const queue = mtl.MTLDeviceNewCommandQueue(handle) orelse
            return error.CommandQueueCreationFailed;

        return .{
            .handle = handle,
            .queue = queue,
        };
    }

    // -------------------------------------------------------------------------
    // Device Info
    // -------------------------------------------------------------------------

    pub fn name(self: Device) ?[*:0]const u8 {
        return mtl.MTLDeviceName(self.handle);
    }

    pub fn hasUnifiedMemory(self: Device) bool {
        return mtl.MTLDeviceHasUnifiedMemory(self.handle);
    }

    pub fn supportsRaytracing(self: Device) bool {
        return mtl.MTLDeviceSupportsRaytracing(self.handle);
    }

    // -------------------------------------------------------------------------
    // Buffer Creation
    // -------------------------------------------------------------------------

    pub fn createBuffer(self: Device, comptime T: type, count: usize, opts: BufferOptions) Error!Buffer(T) {
        const size = count * @sizeOf(T);
        const resource_opts = opts.storage.toResourceOptions();
        const handle = mtl.MTLDeviceNewBufferWithLength(self.handle, size, resource_opts) orelse
            return error.BufferCreationFailed;

        return .{
            .handle = handle,
            .len = count,
            .storage = opts.storage,
        };
    }

    /// Create buffer with default shared storage
    pub fn createBufferShared(self: Device, comptime T: type, count: usize) Error!Buffer(T) {
        return self.createBuffer(T, count, .{});
    }

    /// Create GPU-only buffer (best performance for intermediates)
    pub fn createBufferPrivate(self: Device, comptime T: type, count: usize) Error!Buffer(T) {
        return self.createBuffer(T, count, .{ .storage = .private });
    }

    // -------------------------------------------------------------------------
    // Texture Creation
    // -------------------------------------------------------------------------

    pub fn createTexture(self: Device, desc: TextureDescriptor) Error!Texture {
        const mtl_desc = mtl.MTLTextureDescriptorCreate();
        mtl.MTLTextureDescriptorSetTextureType(mtl_desc, @intFromEnum(desc.texture_type));
        mtl.MTLTextureDescriptorSetPixelFormat(mtl_desc, @intFromEnum(desc.pixel_format));
        mtl.MTLTextureDescriptorSetWidth(mtl_desc, desc.width);
        mtl.MTLTextureDescriptorSetHeight(mtl_desc, desc.height);
        mtl.MTLTextureDescriptorSetDepth(mtl_desc, desc.depth);
        mtl.MTLTextureDescriptorSetMipmapLevelCount(mtl_desc, desc.mipmap_levels);
        mtl.MTLTextureDescriptorSetArrayLength(mtl_desc, desc.array_length);
        mtl.MTLTextureDescriptorSetUsage(mtl_desc, desc.usage.toMtl());
        mtl.MTLTextureDescriptorSetStorageMode(mtl_desc, @intFromEnum(desc.storage));

        const handle = mtl.MTLDeviceNewTextureWithDescriptor(self.handle, mtl_desc) orelse
            return error.TextureCreationFailed;

        return .{
            .handle = handle,
            .width = desc.width,
            .height = desc.height,
            .depth = desc.depth,
            .pixel_format = desc.pixel_format,
        };
    }

    /// Convenience: create 2D texture
    pub fn createTexture2d(self: Device, width: u32, height: u32, format: PixelFormat, usage: TextureUsage) Error!Texture {
        return self.createTexture(.{
            .width = width,
            .height = height,
            .pixel_format = format,
            .usage = usage,
        });
    }

    // -------------------------------------------------------------------------
    // Pipeline Creation
    // -------------------------------------------------------------------------

    pub fn createComputePipeline(self: Device, desc: ComputePipelineDescriptor) Error!ComputePipeline {
        // Compile library from source
        var compile_error: mtl.NSErrorRef = null;
        const library = mtl.MTLDeviceNewLibraryWithSource(
            self.handle,
            desc.source,
            null,
            &compile_error,
        ) orelse {
            if (compile_error) |err| {
                const err_desc = mtl.NSErrorLocalizedDescription(err);
                if (err_desc) |d| {
                    std.debug.print("Shader compilation failed: {s}\n", .{d});
                }
            }
            return error.LibraryCompilationFailed;
        };

        // Get function
        const func = mtl.MTLLibraryNewFunctionWithName(library, desc.function) orelse
            return error.FunctionNotFound;

        // Create pipeline
        var pipeline_error: mtl.NSErrorRef = null;
        const handle = mtl.MTLDeviceNewComputePipelineStateWithFunction(
            self.handle,
            func,
            &pipeline_error,
        ) orelse {
            if (pipeline_error) |err| {
                const err_desc = mtl.NSErrorLocalizedDescription(err);
                if (err_desc) |d| {
                    std.debug.print("Pipeline creation failed: {s}\n", .{d});
                }
            }
            return error.PipelineCreationFailed;
        };

        return .{ .handle = handle };
    }

    /// Convenience: create pipeline from source and function name
    pub fn createPipeline(self: Device, source: [*:0]const u8, function: [*:0]const u8) Error!ComputePipeline {
        return self.createComputePipeline(.{ .source = source, .function = function });
    }

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    pub fn createEvent(self: Device) Event {
        return .{ .handle = mtl.MTLDeviceNewEvent(self.handle) };
    }

    pub fn createSharedEvent(self: Device) SharedEvent {
        return .{ .handle = mtl.MTLDeviceNewSharedEvent(self.handle) };
    }

    // -------------------------------------------------------------------------
    // Command Buffer Creation
    // -------------------------------------------------------------------------

    pub fn createCommandBuffer(self: Device) Error!CommandBuffer {
        const handle = mtl.MTLCommandQueueCommandBuffer(self.queue) orelse
            return error.CommandBufferCreationFailed;
        return .{
            .handle = handle,
            .device = self.handle,
        };
    }

    /// Alias for createCommandBuffer()
    pub fn createCommand(self: Device) Error!CommandBuffer {
        return self.createCommandBuffer();
    }

    // -------------------------------------------------------------------------
    // Submission
    // -------------------------------------------------------------------------

    /// Submit and wait for completion
    pub fn submit(self: Device, cmd: *CommandBuffer) void {
        _ = self;
        mtl.MTLCommandBufferCommit(cmd.handle);
        mtl.MTLCommandBufferWaitUntilCompleted(cmd.handle);
    }

    /// Submit and return fence for async waiting
    pub fn submitAsync(self: Device, cmd: *CommandBuffer) Fence {
        _ = self;
        mtl.MTLCommandBufferCommit(cmd.handle);
        return .{ .command_buffer = cmd.handle };
    }
};

// =============================================================================
// CommandBuffer - The Orchestrator
// =============================================================================

pub const CommandBuffer = struct {
    handle: mtl.MTLCommandBufferRef,
    device: mtl.MTLDeviceRef,

    // -------------------------------------------------------------------------
    // Encoder Creation
    // -------------------------------------------------------------------------

    pub fn createComputeEncoder(self: CommandBuffer, opts: ComputeEncoderOptions) ComputeEncoder {
        const enc = if (opts.concurrent)
            mtl.MTLCommandBufferComputeCommandEncoderWithDispatchType(self.handle, mtl.MTLDispatchTypeConcurrent)
        else
            mtl.MTLCommandBufferComputeCommandEncoder(self.handle);

        return .{
            .handle = enc,
            .current_pipeline = null,
        };
    }

    pub fn createBlitEncoder(self: CommandBuffer) BlitEncoder {
        return .{
            .handle = mtl.MTLCommandBufferBlitCommandEncoder(self.handle),
        };
    }

    pub fn createAccelEncoder(self: CommandBuffer) AccelEncoder {
        return .{
            .handle = mtl.MTLCommandBufferAccelerationStructureCommandEncoder(self.handle),
            .device = self.device,
        };
    }

    // -------------------------------------------------------------------------
    // Event Signaling (GPU-GPU sync across command buffers)
    // -------------------------------------------------------------------------

    pub fn signal(self: *CommandBuffer, evt: Event, value: u64) void {
        mtl.MTLCommandBufferEncodeSignalEvent(self.handle, evt.handle, value);
    }

    pub fn wait(self: *CommandBuffer, evt: Event, value: u64) void {
        mtl.MTLCommandBufferEncodeWaitForEvent(self.handle, evt.handle, value);
    }

    // -------------------------------------------------------------------------
    // Acceleration Structure Building (simplified API)
    // -------------------------------------------------------------------------

    /// Build a single BLAS from triangle geometry
    ///
    /// Example:
    ///   const blas = cmd.buildBLAS(.{ .vertices = vertex_buf });
    pub fn buildBLAS(self: CommandBuffer, opts: anytype) BLAS {
        const enc_handle = mtl.MTLCommandBufferAccelerationStructureCommandEncoder(self.handle);
        const blas = buildBLASInternal(self.device, enc_handle, opts);
        mtl.MTLAccelerationStructureCommandEncoderEndEncoding(enc_handle);
        return blas;
    }

    /// Build multiple BLASes in a single encoder (more efficient for batches)
    ///
    /// Example:
    ///   const blases = cmd.buildBLASes(.{
    ///       .{ .vertices = mesh1_verts },
    ///       .{ .vertices = mesh2_verts },
    ///       .{ .vertices = mesh3_verts },
    ///   });
    pub fn buildBLASes(self: CommandBuffer, opts_tuple: anytype) BuildBLASesResult(@TypeOf(opts_tuple)) {
        const T = @TypeOf(opts_tuple);
        const info = @typeInfo(T);
        if (info != .@"struct" or !info.@"struct".is_tuple) {
            @compileError("buildBLASes expects a tuple of BLAS options");
        }
        const N = info.@"struct".fields.len;

        const enc_handle = mtl.MTLCommandBufferAccelerationStructureCommandEncoder(self.handle);

        var results: [N]BLAS = undefined;

        inline for (0..N) |i| {
            results[i] = buildBLASInternal(self.device, enc_handle, opts_tuple[i]);
        }

        mtl.MTLAccelerationStructureCommandEncoderEndEncoding(enc_handle);

        return results;
    }

    fn BuildBLASesResult(comptime T: type) type {
        const info = @typeInfo(T);
        if (info != .@"struct" or !info.@"struct".is_tuple) {
            return void;
        }
        return [info.@"struct".fields.len]BLAS;
    }

    /// Build a TLAS from BLAS instances
    ///
    /// Example:
    ///   const tlas = cmd.buildTLAS(.{
    ///       .instances = instance_buf,
    ///       .blas = &.{ blas1, blas2 },
    ///   });
    pub fn buildTLAS(self: CommandBuffer, opts: anytype) TLAS {
        const enc_handle = mtl.MTLCommandBufferAccelerationStructureCommandEncoder(self.handle);
        const tlas = buildTLASInternal(self.device, enc_handle, opts);
        mtl.MTLAccelerationStructureCommandEncoderEndEncoding(enc_handle);
        return tlas;
    }
};

pub const ComputeEncoderOptions = struct {
    concurrent: bool = false,
};

// =============================================================================
// ComputeEncoder
// =============================================================================

pub const ComputeEncoder = struct {
    handle: mtl.MTLComputeCommandEncoderRef,
    current_pipeline: ?ComputePipeline,

    const Self = @This();

    // -------------------------------------------------------------------------
    // Dispatch - Atomic operations with all bindings in one call
    // -------------------------------------------------------------------------

    /// 1D dispatch - complete recipe in one call
    pub fn dispatch1d(self: *Self, pipeline: ComputePipeline, count: usize, opts: anytype) *Self {
        self.applyBindings(pipeline, opts);

        const max_threads = pipeline.maxThreadsPerThreadgroup();
        const threads: usize = @min(max_threads, 1024);
        const groups = (count + threads - 1) / threads;

        mtl.MTLComputeCommandEncoderDispatchThreadgroups(
            self.handle,
            .{ .width = groups, .height = 1, .depth = 1 },
            .{ .width = threads, .height = 1, .depth = 1 },
        );
        return self;
    }

    /// 2D dispatch - complete recipe in one call
    pub fn dispatch2d(self: *Self, pipeline: ComputePipeline, width: usize, height: usize, opts: anytype) *Self {
        self.applyBindings(pipeline, opts);

        const groups_x = (width + 15) / 16;
        const groups_y = (height + 15) / 16;

        mtl.MTLComputeCommandEncoderDispatchThreadgroups(
            self.handle,
            .{ .width = groups_x, .height = groups_y, .depth = 1 },
            .{ .width = 16, .height = 16, .depth = 1 },
        );
        return self;
    }

    /// 3D dispatch - complete recipe in one call
    pub fn dispatch3d(self: *Self, pipeline: ComputePipeline, width: usize, height: usize, depth: usize, opts: anytype) *Self {
        self.applyBindings(pipeline, opts);

        const groups_x = (width + 7) / 8;
        const groups_y = (height + 7) / 8;
        const groups_z = (depth + 7) / 8;

        mtl.MTLComputeCommandEncoderDispatchThreadgroups(
            self.handle,
            .{ .width = groups_x, .height = groups_y, .depth = groups_z },
            .{ .width = 8, .height = 8, .depth = 8 },
        );
        return self;
    }

    /// Full control dispatch with explicit grid/threadgroup sizes
    pub fn dispatch(self: *Self, pipeline: ComputePipeline, groups: Size, threads_per_group: Size, opts: anytype) *Self {
        self.applyBindings(pipeline, opts);

        mtl.MTLComputeCommandEncoderDispatchThreadgroups(
            self.handle,
            groups.toMtl(),
            threads_per_group.toMtl(),
        );
        return self;
    }

    // -------------------------------------------------------------------------
    // Internal: Apply all bindings from options
    // -------------------------------------------------------------------------

    fn applyBindings(self: *Self, pipeline: ComputePipeline, opts: anytype) void {
        // Set pipeline if different
        if (self.current_pipeline == null or self.current_pipeline.?.handle != pipeline.handle) {
            mtl.MTLComputeCommandEncoderSetComputePipelineState(self.handle, pipeline.handle);
            self.current_pipeline = pipeline;
        }

        const T = @TypeOf(opts);
        const info = @typeInfo(T);

        if (info != .@"struct") return;

        // Apply buffer bindings
        if (@hasField(T, "buffers")) {
            const buffers = opts.buffers;
            const buf_info = @typeInfo(@TypeOf(buffers));
            if (buf_info == .@"struct" and buf_info.@"struct".is_tuple) {
                inline for (buffers) |binding| {
                    const buf_handle = getHandle(binding.buf);
                    const offset = if (@hasField(@TypeOf(binding), "offset")) binding.offset else 0;
                    mtl.MTLComputeCommandEncoderSetBuffer(self.handle, buf_handle, offset, binding.index);
                }
            }
        }

        // Apply bytes bindings
        if (@hasField(T, "bytes")) {
            const bytes = opts.bytes;
            const bytes_info = @typeInfo(@TypeOf(bytes));
            if (bytes_info == .@"struct" and bytes_info.@"struct".is_tuple) {
                inline for (bytes) |binding| {
                    const DataType = @TypeOf(binding.data);
                    if (@typeInfo(DataType) == .pointer) {
                        const Child = std.meta.Child(DataType);
                        mtl.MTLComputeCommandEncoderSetBytes(self.handle, @ptrCast(binding.data), @sizeOf(Child), binding.index);
                    } else {
                        mtl.MTLComputeCommandEncoderSetBytes(self.handle, @ptrCast(&binding.data), @sizeOf(DataType), binding.index);
                    }
                }
            }
        }

        // Apply texture bindings
        if (@hasField(T, "textures")) {
            const textures = opts.textures;
            const tex_info = @typeInfo(@TypeOf(textures));
            if (tex_info == .@"struct" and tex_info.@"struct".is_tuple) {
                inline for (textures) |binding| {
                    const tex_handle = if (@hasField(@TypeOf(binding.tex), "handle")) binding.tex.handle else binding.tex;
                    mtl.MTLComputeCommandEncoderSetTexture(self.handle, tex_handle, binding.index);
                }
            }
        }

        // Apply threadgroup memory bindings
        if (@hasField(T, "threadgroups")) {
            const threadgroups = opts.threadgroups;
            const tg_info = @typeInfo(@TypeOf(threadgroups));
            if (tg_info == .@"struct" and tg_info.@"struct".is_tuple) {
                inline for (threadgroups) |binding| {
                    mtl.MTLComputeCommandEncoderSetThreadgroupMemoryLength(self.handle, binding.length, binding.index);
                }
            }
        }

        // Apply acceleration structure bindings
        if (@hasField(T, "accels")) {
            const accels = opts.accels;
            const accel_info = @typeInfo(@TypeOf(accels));
            if (accel_info == .@"struct" and accel_info.@"struct".is_tuple) {
                inline for (accels) |binding| {
                    const AccelType = @TypeOf(binding.accel);
                    const accel_handle = if (@typeInfo(AccelType) == .@"struct" and @hasField(AccelType, "handle"))
                        binding.accel.handle
                    else
                        binding.accel;
                    mtl.MTLComputeCommandEncoderSetAccelerationStructure(self.handle, accel_handle, binding.index);
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // Synchronization
    // -------------------------------------------------------------------------

    /// Memory barrier (for concurrent dispatch mode)
    pub fn barrier(self: *Self, scope: BarrierScope) *Self {
        mtl.MTLComputeCommandEncoderMemoryBarrierWithScope(self.handle, @intFromEnum(scope));
        return self;
    }

    // -------------------------------------------------------------------------
    // Lifecycle
    // -------------------------------------------------------------------------

    /// End encoding
    pub fn end(self: *Self) void {
        mtl.MTLComputeCommandEncoderEndEncoding(self.handle);
    }
};

// =============================================================================
// BlitEncoder
// =============================================================================

pub const BlitEncoder = struct {
    handle: mtl.MTLBlitCommandEncoderRef,

    const Self = @This();

    // -------------------------------------------------------------------------
    // Buffer Copy
    // -------------------------------------------------------------------------

    /// Copy entire buffer
    pub fn copy(self: *Self, src: anytype, dst: anytype) *Self {
        const src_handle = getHandle(src);
        const dst_handle = getHandle(dst);
        const size = getByteSize(src);
        mtl.MTLBlitCommandEncoderCopyFromBuffer(self.handle, src_handle, 0, dst_handle, 0, size);
        return self;
    }

    /// Copy buffer region
    pub fn copyRegion(self: *Self, src: anytype, src_offset: usize, dst: anytype, dst_offset: usize, size: usize) *Self {
        const src_handle = getHandle(src);
        const dst_handle = getHandle(dst);
        mtl.MTLBlitCommandEncoderCopyFromBuffer(self.handle, src_handle, src_offset, dst_handle, dst_offset, size);
        return self;
    }

    // -------------------------------------------------------------------------
    // Buffer Fill
    // -------------------------------------------------------------------------

    /// Fill entire buffer with value
    pub fn fill(self: *Self, buf: anytype, value: u8) *Self {
        const handle = getHandle(buf);
        const size = getByteSize(buf);
        mtl.MTLBlitCommandEncoderFillBuffer(self.handle, handle, 0, size, value);
        return self;
    }

    /// Fill buffer region
    pub fn fillRegion(self: *Self, buf: anytype, offset: usize, size: usize, value: u8) *Self {
        const handle = getHandle(buf);
        mtl.MTLBlitCommandEncoderFillBuffer(self.handle, handle, offset, size, value);
        return self;
    }

    // -------------------------------------------------------------------------
    // Texture Operations
    // -------------------------------------------------------------------------

    pub fn copyTexture(self: *Self, src: Texture, dst: Texture) *Self {
        mtl.MTLBlitCommandEncoderCopyFromTexture(self.handle, src.handle, dst.handle);
        return self;
    }

    pub fn generateMipmaps(self: *Self, tex: Texture) *Self {
        mtl.MTLBlitCommandEncoderGenerateMipmaps(self.handle, tex.handle);
        return self;
    }

    // -------------------------------------------------------------------------
    // Synchronization
    // -------------------------------------------------------------------------

    /// Synchronize managed buffer (macOS)
    pub fn synchronize(self: *Self, resource: anytype) *Self {
        const handle = getHandle(resource);
        mtl.MTLBlitCommandEncoderSynchronizeResource(self.handle, handle);
        return self;
    }

    // -------------------------------------------------------------------------
    // Lifecycle
    // -------------------------------------------------------------------------

    pub fn end(self: *Self) void {
        mtl.MTLBlitCommandEncoderEndEncoding(self.handle);
    }
};

// =============================================================================
// AccelEncoder (for advanced use cases: refit, compact, copy)
// =============================================================================
//
// For simple BLAS/TLAS creation, use:
//   cmd.buildBLAS(.{ .vertices = vertex_buf })
//   cmd.buildBLASes(.{ ... })
//   cmd.buildTLAS(.{ .instances = inst_buf, .blas = &.{...} })
//
// AccelEncoder is exposed for advanced operations like refit and compaction.

pub const AccelEncoder = struct {
    handle: mtl.MTLAccelerationStructureCommandEncoderRef,
    device: mtl.MTLDeviceRef,

    const Self = @This();

    // -------------------------------------------------------------------------
    // Low-level Build (for advanced use cases like refit)
    // -------------------------------------------------------------------------

    pub fn build(
        self: *Self,
        accel_struct: AccelerationStructure,
        descriptor: anytype,
        scratch: anytype,
    ) *Self {
        return self.buildOffset(accel_struct, descriptor, scratch, 0);
    }

    pub fn buildOffset(
        self: *Self,
        accel_struct: AccelerationStructure,
        descriptor: anytype,
        scratch: anytype,
        scratch_offset: usize,
    ) *Self {
        const desc_handle = if (@hasField(@TypeOf(descriptor), "handle")) descriptor.handle else descriptor;
        const scratch_handle = getHandle(scratch);
        mtl.MTLAccelerationStructureCommandEncoderBuildAccelerationStructure(
            self.handle,
            accel_struct.handle,
            desc_handle,
            scratch_handle,
            scratch_offset,
        );
        return self;
    }

    // -------------------------------------------------------------------------
    // Refit
    // -------------------------------------------------------------------------

    pub fn refit(
        self: *Self,
        src: AccelerationStructure,
        descriptor: anytype,
        dst: AccelerationStructure,
        scratch: anytype,
    ) *Self {
        return self.refitOffset(src, descriptor, dst, scratch, 0);
    }

    pub fn refitOffset(
        self: *Self,
        src: AccelerationStructure,
        descriptor: anytype,
        dst: AccelerationStructure,
        scratch: anytype,
        scratch_offset: usize,
    ) *Self {
        const desc_handle = if (@hasField(@TypeOf(descriptor), "handle")) descriptor.handle else descriptor;
        const scratch_handle = getHandle(scratch);
        mtl.MTLAccelerationStructureCommandEncoderRefitAccelerationStructure(
            self.handle,
            src.handle,
            desc_handle,
            dst.handle,
            scratch_handle,
            scratch_offset,
        );
        return self;
    }

    // -------------------------------------------------------------------------
    // Copy
    // -------------------------------------------------------------------------

    pub fn copy(self: *Self, src: AccelerationStructure, dst: AccelerationStructure) *Self {
        mtl.MTLAccelerationStructureCommandEncoderCopyAccelerationStructure(self.handle, src.handle, dst.handle);
        return self;
    }

    pub fn compact(self: *Self, src: AccelerationStructure, dst: AccelerationStructure) *Self {
        mtl.MTLAccelerationStructureCommandEncoderCopyAndCompactAccelerationStructure(self.handle, src.handle, dst.handle);
        return self;
    }

    // -------------------------------------------------------------------------
    // Queries
    // -------------------------------------------------------------------------

    pub fn writeCompactedSize(self: *Self, accel_struct: AccelerationStructure, buf: anytype, offset: usize) *Self {
        const handle = getHandle(buf);
        mtl.MTLAccelerationStructureCommandEncoderWriteCompactedAccelerationStructureSize(
            self.handle,
            accel_struct.handle,
            handle,
            offset,
        );
        return self;
    }

    // -------------------------------------------------------------------------
    // Synchronization
    // -------------------------------------------------------------------------

    pub fn barrier(self: *Self) *Self {
        // Note: Metal uses memoryBarrier for accel encoders
        // This ensures all previous builds complete before subsequent operations
        // MTLAccelerationStructureCommandEncoder doesn't have explicit barrier,
        // but operations within it are serialized. Barrier is implicit between
        // accel encoder and next encoder.
        return self;
    }

    // -------------------------------------------------------------------------
    // Lifecycle
    // -------------------------------------------------------------------------

    /// End encoding
    pub fn end(self: *Self) void {
        mtl.MTLAccelerationStructureCommandEncoderEndEncoding(self.handle);
    }
};

// =============================================================================
// Resource Types
// =============================================================================

pub fn Buffer(comptime T: type) type {
    return struct {
        handle: mtl.MTLBufferRef,
        len: usize,
        storage: StorageMode,

        const Self = @This();

        /// Get CPU-accessible slice (null for private storage)
        pub fn getHostSlice(self: Self) ?[]T {
            if (self.storage == .private) return null;
            const ptr: [*]T = @ptrCast(@alignCast(mtl.MTLBufferContents(self.handle)));
            return ptr[0..self.len];
        }

        /// Byte size of buffer
        pub fn byteSize(self: Self) usize {
            return self.len * @sizeOf(T);
        }

        /// For managed storage: notify GPU of CPU writes
        pub fn didModifyRange(self: Self, offset: usize, length: usize) void {
            if (self.storage == .managed) {
                mtl.MTLBufferDidModifyRange(self.handle, offset * @sizeOf(T), length * @sizeOf(T));
            }
        }
    };
}

pub const Texture = struct {
    handle: mtl.MTLTextureRef,
    width: u32,
    height: u32,
    depth: u32 = 1,
    pixel_format: PixelFormat,

    /// Upload data to entire texture
    pub fn upload(self: Texture, data: []const u8) void {
        self.replaceRegion(data, .{ .width = self.width, .height = self.height });
    }

    /// Download entire texture
    pub fn download(self: Texture, data: []u8) void {
        self.getBytes(data, .{ .width = self.width, .height = self.height });
    }

    pub fn replaceRegion(self: Texture, data: []const u8, region: Region) void {
        const bpp = self.bytesPerPixel();
        const bytes_per_row = region.width * bpp;

        mtl.MTLTextureReplaceRegion(
            self.handle,
            .{
                .origin = .{ .x = region.x, .y = region.y, .z = 0 },
                .size = .{ .width = region.width, .height = region.height, .depth = 1 },
            },
            0,
            0,
            data.ptr,
            bytes_per_row,
            0,
        );
    }

    pub fn getBytes(self: Texture, data: []u8, region: Region) void {
        const bpp = self.bytesPerPixel();
        const bytes_per_row = region.width * bpp;

        mtl.MTLTextureGetBytes(
            self.handle,
            data.ptr,
            bytes_per_row,
            0,
            .{
                .origin = .{ .x = region.x, .y = region.y, .z = 0 },
                .size = .{ .width = region.width, .height = region.height, .depth = 1 },
            },
            0,
            0,
        );
    }

    fn bytesPerPixel(self: Texture) u32 {
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

    pub const Region = struct {
        x: u32 = 0,
        y: u32 = 0,
        width: u32,
        height: u32,
    };
};

pub const ComputePipeline = struct {
    handle: mtl.MTLComputePipelineStateRef,

    pub fn maxThreadsPerThreadgroup(self: ComputePipeline) usize {
        return mtl.MTLComputePipelineStateMaxTotalThreadsPerThreadgroup(self.handle);
    }
};

pub const AccelerationStructure = struct {
    handle: mtl.MTLAccelerationStructureRef,

    pub fn size(self: AccelerationStructure) u64 {
        return mtl.MTLAccelerationStructureSize(self.handle);
    }
};

/// Bottom-Level Acceleration Structure (BLAS) - contains triangle/bounding box geometry
/// Created via device.createBLAS()
pub const BLAS = struct {
    handle: mtl.MTLAccelerationStructureRef,
    descriptor: mtl.MTLPrimitiveAccelerationStructureDescriptorRef,
    scratch: mtl.MTLBufferRef, // Kept for potential refit operations

    pub fn size(self: BLAS) u64 {
        return mtl.MTLAccelerationStructureSize(self.handle);
    }
};

/// Top-Level Acceleration Structure (TLAS) - contains instances of BLAS with transforms
/// Created via device.createTLAS()
pub const TLAS = struct {
    handle: mtl.MTLAccelerationStructureRef,
    descriptor: mtl.MTLInstanceAccelerationStructureDescriptorRef,
    scratch: mtl.MTLBufferRef,

    pub fn size(self: TLAS) u64 {
        return mtl.MTLAccelerationStructureSize(self.handle);
    }
};

/// Instance descriptor for TLAS - matches Metal's MTLAccelerationStructureInstanceDescriptor
/// Pack this into a buffer and pass to device.createTLAS()
pub const MTLAccelerationStructureInstanceDescriptor = extern struct {
    /// 4x3 transformation matrix (column-major, last row implicitly [0,0,0,1])
    transform: [4][3]f32 = .{
        .{ 1, 0, 0 }, // column 0
        .{ 0, 1, 0 }, // column 1
        .{ 0, 0, 1 }, // column 2
        .{ 0, 0, 0 }, // column 3 (translation)
    },
    /// Options (MTLAccelerationStructureInstanceOptions)
    options: u32 = 0,
    /// Visibility mask for ray intersection
    mask: u32 = 0xFF,
    /// Offset into intersection function table
    intersection_function_table_offset: u32 = 0,
    /// Index into the BLAS array passed to createTLAS
    acceleration_structure_index: u32 = 0,
};

// =============================================================================
// Synchronization Primitives
// =============================================================================

pub const Fence = struct {
    command_buffer: mtl.MTLCommandBufferRef,

    pub fn wait(self: Fence) void {
        mtl.MTLCommandBufferWaitUntilCompleted(self.command_buffer);
    }
};

pub const Event = struct {
    handle: mtl.MTLEventRef,
};

pub const SharedEvent = struct {
    handle: mtl.MTLSharedEventRef,

    pub fn signaledValue(self: SharedEvent) u64 {
        return mtl.MTLSharedEventSignaledValue(self.handle);
    }

    pub fn setSignaledValue(self: SharedEvent, value: u64) void {
        mtl.MTLSharedEventSetSignaledValue(self.handle, value);
    }
};

// =============================================================================
// Descriptors
// =============================================================================

pub const BufferOptions = struct {
    storage: StorageMode = .shared,
};

pub const TextureDescriptor = struct {
    texture_type: TextureType = .@"2d",
    pixel_format: PixelFormat = .rgba8unorm,
    width: u32 = 1,
    height: u32 = 1,
    depth: u32 = 1,
    mipmap_levels: u32 = 1,
    array_length: u32 = 1,
    usage: TextureUsage = .{ .read = true, .write = true },
    storage: StorageMode = .shared,
};

pub const ComputePipelineDescriptor = struct {
    source: [*:0]const u8,
    function: [*:0]const u8,
};

// =============================================================================
// Enums
// =============================================================================

pub const StorageMode = enum(u32) {
    shared = 0,
    managed = 1,
    private = 2,

    fn toResourceOptions(self: StorageMode) u64 {
        return @as(u64, @intFromEnum(self)) << 4;
    }
};

pub const TextureType = enum(u32) {
    @"1d" = 0,
    @"1d_array" = 1,
    @"2d" = 2,
    @"2d_array" = 3,
    @"2d_multisample" = 4,
    cube = 5,
    cube_array = 6,
    @"3d" = 7,
};

pub const PixelFormat = enum(u32) {
    r8unorm = 10,
    r16float = 25,
    rg8unorm = 30,
    r32float = 55,
    rg16float = 65,
    rgba8unorm = 70,
    rgba8unorm_srgb = 71,
    rgba8snorm = 72,
    rgba8uint = 73,
    rgba8sint = 74,
    bgra8unorm = 80,
    bgra8unorm_srgb = 81,
    rg32float = 105,
    rgba16float = 115,
    rgba32float = 125,
};

pub const TextureUsage = struct {
    read: bool = false,
    write: bool = false,
    render_target: bool = false,

    fn toMtl(self: TextureUsage) u32 {
        var result: u32 = 0;
        if (self.read) result |= 1;
        if (self.write) result |= 2;
        if (self.render_target) result |= 4;
        return result;
    }
};

pub const BarrierScope = enum(u32) {
    buffers = 1,
    textures = 2,
    render_targets = 4,

    pub fn all() BarrierScope {
        return @enumFromInt(1 | 2);
    }
};

pub const IndexType = enum(u32) {
    uint16 = 0,
    uint32 = 1,
};

pub const Size = struct {
    width: usize = 1,
    height: usize = 1,
    depth: usize = 1,

    fn toMtl(self: Size) mtl.MTLSize {
        return .{
            .width = self.width,
            .height = self.height,
            .depth = self.depth,
        };
    }
};

// =============================================================================
// Helpers
// =============================================================================

fn getHandle(resource: anytype) mtl.MTLBufferRef {
    const T = @TypeOf(resource);
    if (@hasField(T, "handle")) {
        return resource.handle;
    } else {
        return resource;
    }
}

fn getByteSize(resource: anytype) usize {
    const T = @TypeOf(resource);
    if (@hasDecl(T, "byteSize")) {
        return resource.byteSize();
    } else if (@hasField(T, "len")) {
        return resource.len;
    } else {
        return 0;
    }
}

/// Internal helper for building a BLAS - used by both single and batch APIs
fn buildBLASInternal(device: mtl.MTLDeviceRef, enc: mtl.MTLAccelerationStructureCommandEncoderRef, opts: anytype) BLAS {
    const T = @TypeOf(opts);

    // Get vertex buffer
    const vertex_buf = opts.vertices;
    const vertex_handle = getHandle(vertex_buf);

    // Infer vertex stride from buffer's element type, or use override
    const vertex_stride: u64 = if (@hasField(T, "vertex_stride"))
        opts.vertex_stride
    else if (@hasField(@TypeOf(vertex_buf), "ElementType"))
        @sizeOf(vertex_buf.ElementType)
    else
        @sizeOf(f32) * 3; // Default: packed float3

    // Create geometry descriptor
    const geo_desc = mtl.MTLAccelerationStructureTriangleGeometryDescriptorCreate();
    mtl.MTLAccelerationStructureTriangleGeometryDescriptorSetVertexBuffer(geo_desc, vertex_handle);
    mtl.MTLAccelerationStructureTriangleGeometryDescriptorSetVertexBufferOffset(geo_desc, 0);
    mtl.MTLAccelerationStructureTriangleGeometryDescriptorSetVertexStride(geo_desc, vertex_stride);

    // Handle optional index buffer
    var triangle_count: u64 = undefined;
    if (@hasField(T, "indices")) {
        const index_buf = opts.indices;
        const index_handle = getHandle(index_buf);
        mtl.MTLAccelerationStructureTriangleGeometryDescriptorSetIndexBuffer(geo_desc, index_handle);
        mtl.MTLAccelerationStructureTriangleGeometryDescriptorSetIndexBufferOffset(geo_desc, 0);

        // Determine index type from buffer element type
        const IndexElem = if (@hasField(@TypeOf(index_buf), "ElementType")) index_buf.ElementType else u32;
        const index_type: u32 = if (IndexElem == u16) @intFromEnum(IndexType.uint16) else @intFromEnum(IndexType.uint32);
        mtl.MTLAccelerationStructureTriangleGeometryDescriptorSetIndexType(geo_desc, index_type);

        // Triangle count from indices
        triangle_count = if (@hasField(T, "triangle_count"))
            opts.triangle_count
        else if (@hasField(@TypeOf(index_buf), "len"))
            index_buf.len / 3
        else
            1;
    } else {
        // Triangle count from vertices (non-indexed)
        triangle_count = if (@hasField(T, "triangle_count"))
            opts.triangle_count
        else if (@hasField(@TypeOf(vertex_buf), "len"))
            vertex_buf.len / 3
        else
            1;
    }
    mtl.MTLAccelerationStructureTriangleGeometryDescriptorSetTriangleCount(geo_desc, triangle_count);

    // Create primitive acceleration structure descriptor
    const prim_desc = mtl.MTLPrimitiveAccelerationStructureDescriptorCreate();
    var geo_handles = [_]*anyopaque{geo_desc.?};
    mtl.MTLPrimitiveAccelerationStructureDescriptorSetGeometryDescriptors(prim_desc, @ptrCast(&geo_handles), 1);

    // Query sizes
    const sizes = mtl.MTLDeviceGetAccelerationStructureSizes(device, prim_desc);

    // Allocate acceleration structure
    const accel_handle = mtl.MTLDeviceNewAccelerationStructureWithSize(device, sizes.accelerationStructureSize);

    // Allocate scratch buffer (temporary, private storage)
    const scratch_handle = mtl.MTLDeviceNewBufferWithLength(device, sizes.buildScratchBufferSize, StorageMode.private.toResourceOptions());

    // Build
    mtl.MTLAccelerationStructureCommandEncoderBuildAccelerationStructure(enc, accel_handle, prim_desc, scratch_handle, 0);

    return .{
        .handle = accel_handle,
        .descriptor = prim_desc,
        .scratch = scratch_handle,
    };
}

/// Internal helper for building a TLAS
fn buildTLASInternal(device: mtl.MTLDeviceRef, enc: mtl.MTLAccelerationStructureCommandEncoderRef, opts: anytype) TLAS {
    const instance_buf = opts.instances;
    const instance_handle = getHandle(instance_buf);
    const blas_list = opts.blas;

    // Get instance count
    const instance_count: u64 = if (@hasField(@TypeOf(instance_buf), "len"))
        instance_buf.len
    else
        1;

    // Create instance acceleration structure descriptor
    const inst_desc = mtl.MTLInstanceAccelerationStructureDescriptorCreate();
    mtl.MTLInstanceAccelerationStructureDescriptorSetInstanceDescriptorBuffer(inst_desc, instance_handle);
    mtl.MTLInstanceAccelerationStructureDescriptorSetInstanceDescriptorBufferOffset(inst_desc, 0);
    mtl.MTLInstanceAccelerationStructureDescriptorSetInstanceDescriptorStride(inst_desc, @sizeOf(MTLAccelerationStructureInstanceDescriptor));
    mtl.MTLInstanceAccelerationStructureDescriptorSetInstanceCount(inst_desc, instance_count);

    // Collect BLAS handles
    var blas_handles: [256]mtl.MTLAccelerationStructureRef = undefined;
    const blas_count = @min(blas_list.len, 256);
    for (0..blas_count) |i| {
        blas_handles[i] = blas_list[i].handle;
    }
    mtl.MTLInstanceAccelerationStructureDescriptorSetInstancedAccelerationStructures(inst_desc, @ptrCast(&blas_handles), blas_count);

    // Query sizes
    const sizes = mtl.MTLDeviceGetAccelerationStructureSizes(device, inst_desc);

    // Allocate acceleration structure
    const accel_handle = mtl.MTLDeviceNewAccelerationStructureWithSize(device, sizes.accelerationStructureSize);

    // Allocate scratch buffer
    const scratch_handle = mtl.MTLDeviceNewBufferWithLength(device, sizes.buildScratchBufferSize, StorageMode.private.toResourceOptions());

    // Build
    mtl.MTLAccelerationStructureCommandEncoderBuildAccelerationStructure(enc, accel_handle, inst_desc, scratch_handle, 0);

    return .{
        .handle = accel_handle,
        .descriptor = inst_desc,
        .scratch = scratch_handle,
    };
}
