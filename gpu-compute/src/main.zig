const std = @import("std");

// Metal exposes a C function to get the default GPU device
// We declare it as an external symbol that will be resolved at link time
extern "c" fn MTLCreateSystemDefaultDevice() ?*anyopaque;

pub fn main() void {
    const device = MTLCreateSystemDefaultDevice();

    if (device) |_| {
        std.debug.print("✓ Got Metal device!\n", .{});
    } else {
        std.debug.print("✗ Metal not available\n", .{});
    }
}
