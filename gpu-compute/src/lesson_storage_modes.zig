const std = @import("std");
const metal = @import("metal.zig");

pub fn main() !void {
    const COUNT: usize = 1024;

    const device = try metal.Device.create();

    // Shared buffer
    const shared = try device.createBuffer(f32, COUNT, .{ .storage = .shared });

    // Map to cpu and write data
    const mapped = shared.getHostSlice().?;
    for (0..COUNT) |i| {
        mapped[i] = @floatFromInt(42);
    }

    // Private buffer
    const private = try device.createBuffer(f32, COUNT, .{ .storage = .private });

    // Copy data from shared buffer to private buffer
    var cmd = try device.createCommand();
    {
        var enc = cmd.blitEncoder();
        defer enc.end();

        enc.copy(shared, private);
    }

    std.debug.print("WOW", .{});
}
