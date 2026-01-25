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
    EncoderCreationFailed,
    LibraryCompilationFailed,
    FunctionNotFound,
    PipelineCreationFailed,
    BufferCreationFailed,
    TextureCreationFailed,
    AccelerationStructureCreationFailed,
    SamplerCreationFailed,
    HeapCreationFailed,
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
    // Acceleration Structures
    // -------------------------------------------------------------------------

    pub fn createAccelerationStructure(self: Device, size: u64) Error!AccelerationStructure {
        const handle = mtl.MTLDeviceNewAccelerationStructureWithSize(self.handle, size) orelse
            return error.AccelerationStructureCreationFailed;
        return .{ .handle = handle };
    }

    pub fn accelSizes(self: Device, descriptor: anytype) AccelSizes {
        const desc_handle = if (@hasField(@TypeOf(descriptor), "handle")) descriptor.handle else descriptor;
        const sizes = mtl.MTLDeviceGetAccelerationStructureSizes(self.handle, desc_handle);
        return .{
            .acceleration_structure_size = sizes.accelerationStructureSize,
            .build_scratch_buffer_size = sizes.buildScratchBufferSize,
            .refit_scratch_buffer_size = sizes.refitScratchBufferSize,
        };
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
            .current_encoder = null,
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
        cmd.endCurrentEncoder();
        mtl.MTLCommandBufferCommit(cmd.handle);
        mtl.MTLCommandBufferWaitUntilCompleted(cmd.handle);
    }

    /// Submit and return fence for async waiting
    pub fn submitAsync(self: Device, cmd: *CommandBuffer) Fence {
        _ = self;
        cmd.endCurrentEncoder();
        mtl.MTLCommandBufferCommit(cmd.handle);
        return .{ .command_buffer = cmd.handle };
    }
};

// =============================================================================
// CommandBuffer - The Orchestrator
// =============================================================================

pub const CommandBuffer = struct {
    handle: mtl.MTLCommandBufferRef,
    current_encoder: ?EncoderHandle,

    // Storage for encoders so we can return pointers for chaining
    compute_encoder: ComputeEncoder = undefined,
    blit_encoder: BlitEncoder = undefined,
    accel_encoder: AccelEncoder = undefined,

    const EncoderHandle = union(enum) {
        compute: mtl.MTLComputeCommandEncoderRef,
        blit: mtl.MTLBlitCommandEncoderRef,
        accel: mtl.MTLAccelerationStructureCommandEncoderRef,
        // render: mtl.MTLRenderCommandEncoderRef, // TODO
    };

    /// End any active encoder
    fn endCurrentEncoder(self: *CommandBuffer) void {
        if (self.current_encoder) |enc| {
            switch (enc) {
                .compute => |e| mtl.MTLComputeCommandEncoderEndEncoding(e),
                .blit => |e| mtl.MTLBlitCommandEncoderEndEncoding(e),
                .accel => |e| mtl.MTLAccelerationStructureCommandEncoderEndEncoding(e),
            }
            self.current_encoder = null;
        }
    }

    // -------------------------------------------------------------------------
    // Encoder Creation
    // -------------------------------------------------------------------------

    pub fn createComputeEncoder(self: *CommandBuffer, pipeline: ComputePipeline, opts: ComputeEncoderOptions) *ComputeEncoder {
        self.endCurrentEncoder();

        const enc = if (opts.concurrent)
            mtl.MTLCommandBufferComputeCommandEncoderWithDispatchType(self.handle, mtl.MTLDispatchTypeConcurrent)
        else
            mtl.MTLCommandBufferComputeCommandEncoder(self.handle);

        self.current_encoder = .{ .compute = enc };

        // Set initial pipeline
        mtl.MTLComputeCommandEncoderSetComputePipelineState(enc, pipeline.handle);

        self.compute_encoder = .{
            .handle = enc,
            .cmd = self,
            .current_pipeline = pipeline,
        };
        return &self.compute_encoder;
    }

    pub fn createBlitEncoder(self: *CommandBuffer) *BlitEncoder {
        self.endCurrentEncoder();

        const enc = mtl.MTLCommandBufferBlitCommandEncoder(self.handle);
        self.current_encoder = .{ .blit = enc };

        self.blit_encoder = .{
            .handle = enc,
            .cmd = self,
        };
        return &self.blit_encoder;
    }

    pub fn createAccelEncoder(self: *CommandBuffer) *AccelEncoder {
        self.endCurrentEncoder();

        const enc = mtl.MTLCommandBufferAccelerationStructureCommandEncoder(self.handle);
        self.current_encoder = .{ .accel = enc };

        self.accel_encoder = .{
            .handle = enc,
            .cmd = self,
        };
        return &self.accel_encoder;
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
};

pub const ComputeEncoderOptions = struct {
    concurrent: bool = false,
};

// =============================================================================
// ComputeEncoder
// =============================================================================

pub const ComputeEncoder = struct {
    handle: mtl.MTLComputeCommandEncoderRef,
    cmd: *CommandBuffer,
    current_pipeline: ComputePipeline,

    const Self = @This();

    // -------------------------------------------------------------------------
    // Pipeline
    // -------------------------------------------------------------------------

    /// Switch pipeline (cheap within same encoder!)
    pub fn setPipeline(self: *Self, p: ComputePipeline) *Self {
        mtl.MTLComputeCommandEncoderSetComputePipelineState(self.handle, p.handle);
        self.current_pipeline = p;
        return self;
    }

    // -------------------------------------------------------------------------
    // Buffer Binding
    // -------------------------------------------------------------------------

    /// Bind single buffer at index
    pub fn setBuffer(self: *Self, buf: anytype, index: u32) *Self {
        return self.setBufferOffset(buf, index, 0);
    }

    /// Bind single buffer at index with offset
    pub fn setBufferOffset(self: *Self, buf: anytype, index: u32, offset: usize) *Self {
        const handle = getHandle(buf);
        mtl.MTLComputeCommandEncoderSetBuffer(self.handle, handle, offset, index);
        return self;
    }

    /// Bind multiple buffers starting at index 0
    pub fn setBuffers(self: *Self, bufs: anytype) *Self {
        const info = @typeInfo(@TypeOf(bufs));
        if (info == .@"struct" and info.@"struct".is_tuple) {
            inline for (bufs, 0..) |b, i| {
                _ = self.setBuffer(b, @intCast(i));
            }
        }
        return self;
    }

    // -------------------------------------------------------------------------
    // Texture Binding
    // -------------------------------------------------------------------------

    pub fn setTexture(self: *Self, tex: Texture, index: u32) *Self {
        mtl.MTLComputeCommandEncoderSetTexture(self.handle, tex.handle, index);
        return self;
    }

    pub fn setTextures(self: *Self, texs: anytype) *Self {
        const info = @typeInfo(@TypeOf(texs));
        if (info == .@"struct" and info.@"struct".is_tuple) {
            inline for (texs, 0..) |t, i| {
                _ = self.setTexture(t, @intCast(i));
            }
        }
        return self;
    }

    // -------------------------------------------------------------------------
    // Bytes (Inline Uniform Data)
    // -------------------------------------------------------------------------

    pub fn setBytes(self: *Self, data: anytype, index: u32) *Self {
        const T = @TypeOf(data);
        if (@typeInfo(T) == .pointer) {
            const Child = std.meta.Child(T);
            mtl.MTLComputeCommandEncoderSetBytes(self.handle, @ptrCast(data), @sizeOf(Child), index);
        } else {
            mtl.MTLComputeCommandEncoderSetBytes(self.handle, @ptrCast(&data), @sizeOf(T), index);
        }
        return self;
    }

    // -------------------------------------------------------------------------
    // Acceleration Structure Binding (for ray tracing)
    // -------------------------------------------------------------------------

    pub fn setAccelerationStructure(self: *Self, as: AccelerationStructure, index: u32) *Self {
        mtl.MTLComputeCommandEncoderSetAccelerationStructure(self.handle, as.handle, index);
        return self;
    }

    // -------------------------------------------------------------------------
    // Threadgroup Memory
    // -------------------------------------------------------------------------

    pub fn setThreadgroupMemory(self: *Self, length: usize, index: u32) *Self {
        mtl.MTLComputeCommandEncoderSetThreadgroupMemoryLength(self.handle, length, index);
        return self;
    }

    // -------------------------------------------------------------------------
    // Dispatch
    // -------------------------------------------------------------------------

    /// Full control dispatch
    pub fn dispatch(self: *Self, groups: Size, threads_per_group: Size) *Self {
        mtl.MTLComputeCommandEncoderDispatchThreadgroups(
            self.handle,
            groups.toMtl(),
            threads_per_group.toMtl(),
        );
        return self;
    }

    /// 1D dispatch - auto-calculates threadgroups based on pipeline
    pub fn dispatch1d(self: *Self, count: usize) *Self {
        const max_threads = self.current_pipeline.maxThreadsPerThreadgroup();
        const threads: usize = @min(max_threads, 1024);
        const groups = (count + threads - 1) / threads;
        return self.dispatch(
            .{ .width = groups },
            .{ .width = threads },
        );
    }

    /// 2D dispatch - uses 16x16 threadgroups
    pub fn dispatch2d(self: *Self, width: usize, height: usize) *Self {
        const groups_x = (width + 15) / 16;
        const groups_y = (height + 15) / 16;
        return self.dispatch(
            .{ .width = groups_x, .height = groups_y },
            .{ .width = 16, .height = 16 },
        );
    }

    /// 3D dispatch
    pub fn dispatch3d(self: *Self, width: usize, height: usize, depth: usize) *Self {
        const groups_x = (width + 7) / 8;
        const groups_y = (height + 7) / 8;
        const groups_z = (depth + 7) / 8;
        return self.dispatch(
            .{ .width = groups_x, .height = groups_y, .depth = groups_z },
            .{ .width = 8, .height = 8, .depth = 8 },
        );
    }

    /// Indirect dispatch - GPU-driven workloads
    pub fn dispatchIndirect(self: *Self, buf: anytype, offset: usize) *Self {
        const handle = getHandle(buf);
        const threads = self.current_pipeline.maxThreadsPerThreadgroup();
        mtl.MTLComputeCommandEncoderDispatchThreadgroupsWithIndirectBuffer(
            self.handle,
            handle,
            offset,
            mtl.MTLSize{ .width = threads, .height = 1, .depth = 1 },
        );
        return self;
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

    /// End encoding - call at end of chain or use auto-end on next encoder/submit
    pub fn end(self: *Self) void {
        if (self.cmd.current_encoder) |enc| {
            if (enc == .compute and enc.compute == self.handle) {
                mtl.MTLComputeCommandEncoderEndEncoding(self.handle);
                self.cmd.current_encoder = null;
            }
        }
    }
};

// =============================================================================
// BlitEncoder
// =============================================================================

pub const BlitEncoder = struct {
    handle: mtl.MTLBlitCommandEncoderRef,
    cmd: *CommandBuffer,

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
        if (self.cmd.current_encoder) |enc| {
            if (enc == .blit and enc.blit == self.handle) {
                mtl.MTLBlitCommandEncoderEndEncoding(self.handle);
                self.cmd.current_encoder = null;
            }
        }
    }
};

// =============================================================================
// AccelEncoder
// =============================================================================

pub const AccelEncoder = struct {
    handle: mtl.MTLAccelerationStructureCommandEncoderRef,
    cmd: *CommandBuffer,

    const Self = @This();

    // -------------------------------------------------------------------------
    // Build
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

    pub fn end(self: *Self) void {
        if (self.cmd.current_encoder) |enc| {
            if (enc == .accel and enc.accel == self.handle) {
                mtl.MTLAccelerationStructureCommandEncoderEndEncoding(self.handle);
                self.cmd.current_encoder = null;
            }
        }
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

pub const AccelSizes = struct {
    acceleration_structure_size: u64,
    build_scratch_buffer_size: u64,
    refit_scratch_buffer_size: u64,
};

// =============================================================================
// Acceleration Structure Descriptors
// =============================================================================

pub const TriangleGeometryDescriptor = struct {
    handle: mtl.MTLAccelerationStructureTriangleGeometryDescriptorRef,

    pub fn init() TriangleGeometryDescriptor {
        return .{ .handle = mtl.MTLAccelerationStructureTriangleGeometryDescriptorCreate() };
    }

    pub fn vertexBuffer(self: TriangleGeometryDescriptor, buf: anytype, stride: u64) TriangleGeometryDescriptor {
        return self.vertexBufferOffset(buf, 0, stride);
    }

    pub fn vertexBufferOffset(self: TriangleGeometryDescriptor, buf: anytype, offset: u64, stride: u64) TriangleGeometryDescriptor {
        const handle = getHandle(buf);
        mtl.MTLAccelerationStructureTriangleGeometryDescriptorSetVertexBuffer(self.handle, handle);
        mtl.MTLAccelerationStructureTriangleGeometryDescriptorSetVertexBufferOffset(self.handle, offset);
        mtl.MTLAccelerationStructureTriangleGeometryDescriptorSetVertexStride(self.handle, stride);
        return self;
    }

    pub fn indexBuffer(self: TriangleGeometryDescriptor, buf: anytype, index_type: IndexType) TriangleGeometryDescriptor {
        return self.indexBufferOffset(buf, index_type, 0);
    }

    pub fn indexBufferOffset(self: TriangleGeometryDescriptor, buf: anytype, index_type: IndexType, offset: u64) TriangleGeometryDescriptor {
        const handle = getHandle(buf);
        mtl.MTLAccelerationStructureTriangleGeometryDescriptorSetIndexBuffer(self.handle, handle);
        mtl.MTLAccelerationStructureTriangleGeometryDescriptorSetIndexBufferOffset(self.handle, offset);
        mtl.MTLAccelerationStructureTriangleGeometryDescriptorSetIndexType(self.handle, @intFromEnum(index_type));
        return self;
    }

    pub fn triangleCount(self: TriangleGeometryDescriptor, count: u64) TriangleGeometryDescriptor {
        mtl.MTLAccelerationStructureTriangleGeometryDescriptorSetTriangleCount(self.handle, count);
        return self;
    }
};

pub const BoundingBoxGeometryDescriptor = struct {
    handle: mtl.MTLAccelerationStructureBoundingBoxGeometryDescriptorRef,

    pub fn init() BoundingBoxGeometryDescriptor {
        return .{ .handle = mtl.MTLAccelerationStructureBoundingBoxGeometryDescriptorCreate() };
    }

    pub fn boundingBoxBuffer(self: BoundingBoxGeometryDescriptor, buf: anytype, stride: u64) BoundingBoxGeometryDescriptor {
        return self.boundingBoxBufferOffset(buf, 0, stride);
    }

    pub fn boundingBoxBufferOffset(self: BoundingBoxGeometryDescriptor, buf: anytype, offset: u64, stride: u64) BoundingBoxGeometryDescriptor {
        const handle = getHandle(buf);
        mtl.MTLAccelerationStructureBoundingBoxGeometryDescriptorSetBoundingBoxBuffer(self.handle, handle);
        mtl.MTLAccelerationStructureBoundingBoxGeometryDescriptorSetBoundingBoxBufferOffset(self.handle, offset);
        mtl.MTLAccelerationStructureBoundingBoxGeometryDescriptorSetBoundingBoxStride(self.handle, stride);
        return self;
    }

    pub fn boundingBoxCount(self: BoundingBoxGeometryDescriptor, count: u64) BoundingBoxGeometryDescriptor {
        mtl.MTLAccelerationStructureBoundingBoxGeometryDescriptorSetBoundingBoxCount(self.handle, count);
        return self;
    }
};

pub const PrimitiveAccelerationStructureDescriptor = struct {
    handle: mtl.MTLPrimitiveAccelerationStructureDescriptorRef,
    geometry_handles: [64]*anyopaque = undefined,
    geometry_count: usize = 0,

    pub fn init() PrimitiveAccelerationStructureDescriptor {
        return .{ .handle = mtl.MTLPrimitiveAccelerationStructureDescriptorCreate() };
    }

    pub fn addGeometry(self: *PrimitiveAccelerationStructureDescriptor, geometry: anytype) void {
        if (self.geometry_count >= 64) return;
        const geo_handle = if (@hasField(@TypeOf(geometry), "handle")) geometry.handle else geometry;
        self.geometry_handles[self.geometry_count] = geo_handle.?;
        self.geometry_count += 1;
    }

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

pub const InstanceAccelerationStructureDescriptor = struct {
    handle: mtl.MTLInstanceAccelerationStructureDescriptorRef,
    blas_handles: [256]mtl.MTLAccelerationStructureRef = undefined,
    blas_count: usize = 0,

    pub fn init() InstanceAccelerationStructureDescriptor {
        return .{ .handle = mtl.MTLInstanceAccelerationStructureDescriptorCreate() };
    }

    pub fn instanceDescriptorBuffer(self: InstanceAccelerationStructureDescriptor, buf: anytype, stride: u64) InstanceAccelerationStructureDescriptor {
        return self.instanceDescriptorBufferOffset(buf, 0, stride);
    }

    pub fn instanceDescriptorBufferOffset(self: InstanceAccelerationStructureDescriptor, buf: anytype, offset: u64, stride: u64) InstanceAccelerationStructureDescriptor {
        const handle = getHandle(buf);
        mtl.MTLInstanceAccelerationStructureDescriptorSetInstanceDescriptorBuffer(self.handle, handle);
        mtl.MTLInstanceAccelerationStructureDescriptorSetInstanceDescriptorBufferOffset(self.handle, offset);
        mtl.MTLInstanceAccelerationStructureDescriptorSetInstanceDescriptorStride(self.handle, stride);
        return self;
    }

    pub fn instanceCount(self: InstanceAccelerationStructureDescriptor, count: u64) InstanceAccelerationStructureDescriptor {
        mtl.MTLInstanceAccelerationStructureDescriptorSetInstanceCount(self.handle, count);
        return self;
    }

    pub fn addInstancedAccelerationStructure(self: *InstanceAccelerationStructureDescriptor, accel_struct: AccelerationStructure) void {
        if (self.blas_count >= 256) return;
        self.blas_handles[self.blas_count] = accel_struct.handle;
        self.blas_count += 1;
    }

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
