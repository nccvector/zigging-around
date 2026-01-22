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
};

pub const Device = struct {
    handle: mtl.MTLDeviceRef,

    pub fn default() Error!Device {
        return .{ .handle = mtl.MTLWrapperCreateSystemDefaultDevice() orelse return error.DeviceNotFound };
    }

    pub fn name(self: Device) ?[*:0]const u8 {
        return mtl.MTLDeviceName(self.handle);
    }

    pub fn hasUnifiedMemory(self: Device) bool {
        return mtl.MTLDeviceHasUnifiedMemory(self.handle);
    }

    pub fn createBuffer(self: Device, comptime T: type, count: usize) Error!Buffer(T) {
        const buffer_handle = mtl.MTLDeviceNewBufferWithLength(self.handle, count * @sizeOf(T), 0) orelse return error.BufferCreationFailed;
        return .{
            .handle = buffer_handle,
            .len = count,
        };
    }

    pub fn createLibrary(self: Device, source: [*:0]const u8) Error!Library {
        var compile_error: mtl.NSErrorRef = null;
        const library = mtl.MTLDeviceNewLibraryWithSource(self.handle, source, null, &compile_error) orelse {
            const desc: [*c]const u8 = mtl.NSErrorLocalizedDescription(compile_error) orelse "(unknown error)";
            std.debug.print("Failed to compile shader: {s}", .{desc});
            return error.ShaderCompilationFailed;
        };
        return .{
            .handle = library,
            .device = self.handle,
        };
    }

    pub fn createCommandQueue(self: Device) Error!CommandQueue {
        const queue = mtl.MTLDeviceNewCommandQueue(self.handle) orelse return error.CommandQueueCreationFailed;
        return .{
            .handle = queue,
        };
    }
};

pub fn Buffer(comptime T: type) type {
    return struct {
        handle: mtl.MTLBufferRef,
        len: usize,

        const Self = @This();

        pub fn contents(self: Self) []T {
            const ptr: [*]T = @ptrCast(@alignCast(mtl.MTLBufferContents(self.handle)));
            return ptr[0..self.len];
        }
    };
}

pub const Library = struct {
    handle: mtl.MTLLibraryRef,
    device: mtl.MTLDeviceRef,

    pub fn createComputePipeline(self: Library, func_name: [*:0]const u8) Error!ComputePipeline {
        const func = mtl.MTLLibraryNewFunctionWithName(self.handle, func_name) orelse return error.FunctionNotFound;
        var pipeline_error: mtl.NSErrorRef = null;
        const pipeline_handle = mtl.MTLDeviceNewComputePipelineStateWithFunction(self.device, func, &pipeline_error) orelse {
            const desc: [*c]const u8 = mtl.NSErrorLocalizedDescription(pipeline_error) orelse "(unknown error)";
            std.debug.print("Failed to create add pipeline: {s}\n", .{desc});
            return error.PipelineCreationFailed;
        };

        return .{
            .handle = pipeline_handle,
        };
    }
};

pub const CommandQueue = struct {
    handle: mtl.MTLCommandQueueRef,
};

pub const ComputePipeline = struct {
    handle: mtl.MTLComputePipelineStateRef,

    pub fn maxThreadsPerThreadGroup(self: ComputePipeline) u64 {
        return mtl.MTLComputePipelineStateMaxTotalThreadsPerThreadgroup(self.handle);
    }

    pub fn begin(self: ComputePipeline, queue: CommandQueue) Error!ComputeCommand {
        const command_buffer = mtl.MTLCommandQueueCommandBuffer(queue.handle) orelse return error.CommandBufferCreationFailed;
        const encoder = mtl.MTLCommandBufferComputeCommandEncoder(command_buffer) orelse return error.EncoderCreationFailed;

        mtl.MTLComputeCommandEncoderSetComputePipelineState(encoder, self.handle);

        return .{
            .command_buffer_handle = command_buffer,
            .encoder_handle = encoder,
        };
    }
};

pub const ComputeCommand = struct {
    command_buffer_handle: mtl.MTLCommandBufferRef,
    encoder_handle: mtl.MTLComputeCommandEncoderRef,

    pub fn setBuffer(self: ComputeCommand, comptime T: type, buffer: Buffer(T), offset: u64, index: u64) void {
        mtl.MTLComputeCommandEncoderSetBuffer(self.encoder_handle, buffer.handle, offset, index);
    }

    pub fn dispatch(self: ComputeCommand, grid: Size, threads_per_group: Size) void {
        mtl.MTLComputeCommandEncoderDispatchThreadgroups(
            self.encoder_handle,
            mtl.MTLSize{ .width = grid.width, .height = grid.height, .depth = grid.depth },
            mtl.MTLSize{ .width = threads_per_group.width, .height = threads_per_group.height, .depth = threads_per_group.depth },
        );
    }

    pub fn submit(self: ComputeCommand) void {
        mtl.MTLComputeCommandEncoderEndEncoding(self.encoder_handle);
        mtl.MTLCommandBufferCommit(self.command_buffer_handle);
        mtl.MTLCommandBufferWaitUntilCompleted(self.command_buffer_handle);
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
