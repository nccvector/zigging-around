// Metal Compute Shaders for GPU array operations
#include <metal_stdlib>
using namespace metal;

// Add two arrays element-wise: C[i] = A[i] + B[i]
kernel void vector_add(
    device const float* A [[buffer(0)]],
    device const float* B [[buffer(1)]],
    device float* C [[buffer(2)]],
    uint id [[thread_position_in_grid]]
) {
    C[id] = A[id] + B[id];
}

// Multiply two arrays element-wise: C[i] = A[i] * B[i]
kernel void vector_multiply(
    device const float* A [[buffer(0)]],
    device const float* B [[buffer(1)]],
    device float* C [[buffer(2)]],
    uint id [[thread_position_in_grid]]
) {
    C[id] = A[id] * B[id];
}

// Fused multiply-add: D[i] = A[i] * B[i] + C[i]
kernel void vector_fma(
    device const float* A [[buffer(0)]],
    device const float* B [[buffer(1)]],
    device const float* C [[buffer(2)]],
    device float* D [[buffer(3)]],
    uint id [[thread_position_in_grid]]
) {
    D[id] = fma(A[id], B[id], C[id]);
}

// Scale array by constant: B[i] = A[i] * scale
kernel void vector_scale(
    device const float* A [[buffer(0)]],
    device float* B [[buffer(1)]],
    constant float& scale [[buffer(2)]],
    uint id [[thread_position_in_grid]]
) {
    B[id] = A[id] * scale;
}
