// metal_wrapper.h - Pure C interface to Metal API via metal-cpp
// Naming matches Metal API conventions (CamelCase)

#ifndef METAL_WRAPPER_H
#define METAL_WRAPPER_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// =============================================================================
// Opaque Handle Types
// =============================================================================

typedef void* MTLDeviceRef;
typedef void* MTLCommandQueueRef;
typedef void* MTLCommandBufferRef;
typedef void* MTLBufferRef;
typedef void* MTLTextureRef;
typedef void* MTLSamplerStateRef;
typedef void* MTLLibraryRef;
typedef void* MTLFunctionRef;
typedef void* MTLComputePipelineStateRef;
typedef void* MTLRenderPipelineStateRef;
typedef void* MTLDepthStencilStateRef;
typedef void* MTLComputeCommandEncoderRef;
typedef void* MTLRenderCommandEncoderRef;
typedef void* MTLBlitCommandEncoderRef;
typedef void* MTLParallelRenderCommandEncoderRef;
typedef void* MTLResourceStateCommandEncoderRef;
typedef void* MTLAccelerationStructureCommandEncoderRef;
typedef void* MTLHeapRef;
typedef void* MTLFenceRef;
typedef void* MTLEventRef;
typedef void* MTLSharedEventRef;
typedef void* MTLIndirectCommandBufferRef;
typedef void* MTLAccelerationStructureRef;
typedef void* MTLIntersectionFunctionTableRef;
typedef void* MTLVisibleFunctionTableRef;
typedef void* MTLBinaryArchiveRef;
typedef void* MTLDynamicLibraryRef;
typedef void* MTLCounterSampleBufferRef;
typedef void* MTLArgumentEncoderRef;
typedef void* MTLRasterizationRateMapRef;
typedef void* MTLIOCommandQueueRef;
typedef void* MTLIOCommandBufferRef;
typedef void* MTLIOFileHandleRef;
typedef void* MTLLogStateRef;
typedef void* MTLResidencySetRef;
typedef void* NSErrorRef;
typedef void* NSArrayRef;
typedef void* NSStringRef;
typedef void* AutoreleasePoolRef;

// Descriptor types (these are actual objects we create)
typedef void* MTLTextureDescriptorRef;
typedef void* MTLSamplerDescriptorRef;
typedef void* MTLRenderPipelineDescriptorRef;
typedef void* MTLComputePipelineDescriptorRef;
typedef void* MTLDepthStencilDescriptorRef;
typedef void* MTLRenderPassDescriptorRef;
typedef void* MTLHeapDescriptorRef;
typedef void* MTLCompileOptionsRef;
typedef void* MTLStencilDescriptorRef;
typedef void* MTLVertexDescriptorRef;
typedef void* MTLIndirectCommandBufferDescriptorRef;
typedef void* MTLAccelerationStructureDescriptorRef;

// =============================================================================
// Structs
// =============================================================================

typedef struct {
    uint64_t width;
    uint64_t height;
    uint64_t depth;
} MTLSize;

typedef struct {
    uint64_t x;
    uint64_t y;
    uint64_t z;
} MTLOrigin;

typedef struct {
    MTLOrigin origin;
    MTLSize size;
} MTLRegion;

typedef struct {
    double red;
    double green;
    double blue;
    double alpha;
} MTLClearColor;

typedef struct {
    uint64_t x;
    uint64_t y;
    uint64_t width;
    uint64_t height;
} MTLViewport;

typedef struct {
    uint64_t x;
    uint64_t y;
    uint64_t width;
    uint64_t height;
} MTLScissorRect;

typedef struct {
    uint64_t size;
    uint64_t align;
} MTLSizeAndAlign;

// =============================================================================
// Enums
// =============================================================================

typedef enum {
    MTLPixelFormatInvalid = 0,
    MTLPixelFormatA8Unorm = 1,
    MTLPixelFormatR8Unorm = 10,
    MTLPixelFormatR8Snorm = 12,
    MTLPixelFormatR8Uint = 13,
    MTLPixelFormatR8Sint = 14,
    MTLPixelFormatR16Unorm = 20,
    MTLPixelFormatR16Snorm = 22,
    MTLPixelFormatR16Uint = 23,
    MTLPixelFormatR16Sint = 24,
    MTLPixelFormatR16Float = 25,
    MTLPixelFormatRG8Unorm = 30,
    MTLPixelFormatRG8Snorm = 32,
    MTLPixelFormatRG8Uint = 33,
    MTLPixelFormatRG8Sint = 34,
    MTLPixelFormatR32Uint = 53,
    MTLPixelFormatR32Sint = 54,
    MTLPixelFormatR32Float = 55,
    MTLPixelFormatRG16Unorm = 60,
    MTLPixelFormatRG16Snorm = 62,
    MTLPixelFormatRG16Uint = 63,
    MTLPixelFormatRG16Sint = 64,
    MTLPixelFormatRG16Float = 65,
    MTLPixelFormatRGBA8Unorm = 70,
    MTLPixelFormatRGBA8Unorm_sRGB = 71,
    MTLPixelFormatRGBA8Snorm = 72,
    MTLPixelFormatRGBA8Uint = 73,
    MTLPixelFormatRGBA8Sint = 74,
    MTLPixelFormatBGRA8Unorm = 80,
    MTLPixelFormatBGRA8Unorm_sRGB = 81,
    MTLPixelFormatRGB10A2Unorm = 90,
    MTLPixelFormatRGB10A2Uint = 91,
    MTLPixelFormatRG11B10Float = 92,
    MTLPixelFormatRGB9E5Float = 93,
    MTLPixelFormatRG32Uint = 103,
    MTLPixelFormatRG32Sint = 104,
    MTLPixelFormatRG32Float = 105,
    MTLPixelFormatRGBA16Unorm = 110,
    MTLPixelFormatRGBA16Snorm = 112,
    MTLPixelFormatRGBA16Uint = 113,
    MTLPixelFormatRGBA16Sint = 114,
    MTLPixelFormatRGBA16Float = 115,
    MTLPixelFormatRGBA32Uint = 123,
    MTLPixelFormatRGBA32Sint = 124,
    MTLPixelFormatRGBA32Float = 125,
    MTLPixelFormatDepth16Unorm = 250,
    MTLPixelFormatDepth32Float = 252,
    MTLPixelFormatStencil8 = 253,
    MTLPixelFormatDepth24Unorm_Stencil8 = 255,
    MTLPixelFormatDepth32Float_Stencil8 = 260,
} MTLPixelFormat;

typedef enum {
    MTLResourceStorageModeShared = 0,
    MTLResourceStorageModeManaged = 1,
    MTLResourceStorageModePrivate = 2,
    MTLResourceStorageModeMemoryless = 3,
} MTLStorageMode;

typedef enum {
    MTLResourceCPUCacheModeDefaultCache = 0,
    MTLResourceCPUCacheModeWriteCombined = 1,
} MTLCPUCacheMode;

typedef enum {
    MTLResourceHazardTrackingModeDefault = 0,
    MTLResourceHazardTrackingModeUntracked = 1,
    MTLResourceHazardTrackingModeTracked = 2,
} MTLHazardTrackingMode;

typedef uint64_t MTLResourceOptions;
#define MTLResourceStorageModeShift 4
#define MTLResourceCPUCacheModeShift 0
#define MTLResourceHazardTrackingModeShift 8

typedef enum {
    MTLTextureType1D = 0,
    MTLTextureType1DArray = 1,
    MTLTextureType2D = 2,
    MTLTextureType2DArray = 3,
    MTLTextureType2DMultisample = 4,
    MTLTextureTypeCube = 5,
    MTLTextureTypeCubeArray = 6,
    MTLTextureType3D = 7,
    MTLTextureType2DMultisampleArray = 8,
    MTLTextureTypeTextureBuffer = 9,
} MTLTextureType;

typedef enum {
    MTLTextureUsageUnknown = 0,
    MTLTextureUsageShaderRead = 1,
    MTLTextureUsageShaderWrite = 2,
    MTLTextureUsageRenderTarget = 4,
    MTLTextureUsagePixelFormatView = 16,
} MTLTextureUsage;

typedef enum {
    MTLCommandBufferStatusNotEnqueued = 0,
    MTLCommandBufferStatusEnqueued = 1,
    MTLCommandBufferStatusCommitted = 2,
    MTLCommandBufferStatusScheduled = 3,
    MTLCommandBufferStatusCompleted = 4,
    MTLCommandBufferStatusError = 5,
} MTLCommandBufferStatus;

typedef enum {
    MTLLoadActionDontCare = 0,
    MTLLoadActionLoad = 1,
    MTLLoadActionClear = 2,
} MTLLoadAction;

typedef enum {
    MTLStoreActionDontCare = 0,
    MTLStoreActionStore = 1,
    MTLStoreActionMultisampleResolve = 2,
    MTLStoreActionStoreAndMultisampleResolve = 3,
    MTLStoreActionUnknown = 4,
    MTLStoreActionCustomSampleDepthStore = 5,
} MTLStoreAction;

typedef enum {
    MTLPrimitiveTypePoint = 0,
    MTLPrimitiveTypeLine = 1,
    MTLPrimitiveTypeLineStrip = 2,
    MTLPrimitiveTypeTriangle = 3,
    MTLPrimitiveTypeTriangleStrip = 4,
} MTLPrimitiveType;

typedef enum {
    MTLIndexTypeUInt16 = 0,
    MTLIndexTypeUInt32 = 1,
} MTLIndexType;

typedef enum {
    MTLCompareFunctionNever = 0,
    MTLCompareFunctionLess = 1,
    MTLCompareFunctionEqual = 2,
    MTLCompareFunctionLessEqual = 3,
    MTLCompareFunctionGreater = 4,
    MTLCompareFunctionNotEqual = 5,
    MTLCompareFunctionGreaterEqual = 6,
    MTLCompareFunctionAlways = 7,
} MTLCompareFunction;

typedef enum {
    MTLSamplerMinMagFilterNearest = 0,
    MTLSamplerMinMagFilterLinear = 1,
} MTLSamplerMinMagFilter;

typedef enum {
    MTLSamplerMipFilterNotMipmapped = 0,
    MTLSamplerMipFilterNearest = 1,
    MTLSamplerMipFilterLinear = 2,
} MTLSamplerMipFilter;

typedef enum {
    MTLSamplerAddressModeClampToEdge = 0,
    MTLSamplerAddressModeMirrorClampToEdge = 1,
    MTLSamplerAddressModeRepeat = 2,
    MTLSamplerAddressModeMirrorRepeat = 3,
    MTLSamplerAddressModeClampToZero = 4,
    MTLSamplerAddressModeClampToBorderColor = 5,
} MTLSamplerAddressMode;

typedef enum {
    MTLBlendFactorZero = 0,
    MTLBlendFactorOne = 1,
    MTLBlendFactorSourceColor = 2,
    MTLBlendFactorOneMinusSourceColor = 3,
    MTLBlendFactorSourceAlpha = 4,
    MTLBlendFactorOneMinusSourceAlpha = 5,
    MTLBlendFactorDestinationColor = 6,
    MTLBlendFactorOneMinusDestinationColor = 7,
    MTLBlendFactorDestinationAlpha = 8,
    MTLBlendFactorOneMinusDestinationAlpha = 9,
    MTLBlendFactorSourceAlphaSaturated = 10,
    MTLBlendFactorBlendColor = 11,
    MTLBlendFactorOneMinusBlendColor = 12,
    MTLBlendFactorBlendAlpha = 13,
    MTLBlendFactorOneMinusBlendAlpha = 14,
} MTLBlendFactor;

typedef enum {
    MTLBlendOperationAdd = 0,
    MTLBlendOperationSubtract = 1,
    MTLBlendOperationReverseSubtract = 2,
    MTLBlendOperationMin = 3,
    MTLBlendOperationMax = 4,
} MTLBlendOperation;

typedef enum {
    MTLVertexFormatInvalid = 0,
    MTLVertexFormatUChar2 = 1,
    MTLVertexFormatUChar3 = 2,
    MTLVertexFormatUChar4 = 3,
    MTLVertexFormatChar2 = 4,
    MTLVertexFormatChar3 = 5,
    MTLVertexFormatChar4 = 6,
    MTLVertexFormatUChar2Normalized = 7,
    MTLVertexFormatUChar3Normalized = 8,
    MTLVertexFormatUChar4Normalized = 9,
    MTLVertexFormatChar2Normalized = 10,
    MTLVertexFormatChar3Normalized = 11,
    MTLVertexFormatChar4Normalized = 12,
    MTLVertexFormatUShort2 = 13,
    MTLVertexFormatUShort3 = 14,
    MTLVertexFormatUShort4 = 15,
    MTLVertexFormatShort2 = 16,
    MTLVertexFormatShort3 = 17,
    MTLVertexFormatShort4 = 18,
    MTLVertexFormatUShort2Normalized = 19,
    MTLVertexFormatUShort3Normalized = 20,
    MTLVertexFormatUShort4Normalized = 21,
    MTLVertexFormatShort2Normalized = 22,
    MTLVertexFormatShort3Normalized = 23,
    MTLVertexFormatShort4Normalized = 24,
    MTLVertexFormatHalf2 = 25,
    MTLVertexFormatHalf3 = 26,
    MTLVertexFormatHalf4 = 27,
    MTLVertexFormatFloat = 28,
    MTLVertexFormatFloat2 = 29,
    MTLVertexFormatFloat3 = 30,
    MTLVertexFormatFloat4 = 31,
    MTLVertexFormatInt = 32,
    MTLVertexFormatInt2 = 33,
    MTLVertexFormatInt3 = 34,
    MTLVertexFormatInt4 = 35,
    MTLVertexFormatUInt = 36,
    MTLVertexFormatUInt2 = 37,
    MTLVertexFormatUInt3 = 38,
    MTLVertexFormatUInt4 = 39,
} MTLVertexFormat;

typedef enum {
    MTLVertexStepFunctionConstant = 0,
    MTLVertexStepFunctionPerVertex = 1,
    MTLVertexStepFunctionPerInstance = 2,
    MTLVertexStepFunctionPerPatch = 3,
    MTLVertexStepFunctionPerPatchControlPoint = 4,
} MTLVertexStepFunction;

typedef enum {
    MTLDispatchTypeSerial = 0,
    MTLDispatchTypeConcurrent = 1,
} MTLDispatchType;

typedef enum {
    MTLBarrierScopeBuffers = 1,
    MTLBarrierScopeTextures = 2,
    MTLBarrierScopeRenderTargets = 4,
} MTLBarrierScope;

typedef enum {
    MTLResourceUsageRead = 1,
    MTLResourceUsageWrite = 2,
    MTLResourceUsageSample = 4,
} MTLResourceUsage;

typedef enum {
    MTLGPUFamilyApple1 = 1001,
    MTLGPUFamilyApple2 = 1002,
    MTLGPUFamilyApple3 = 1003,
    MTLGPUFamilyApple4 = 1004,
    MTLGPUFamilyApple5 = 1005,
    MTLGPUFamilyApple6 = 1006,
    MTLGPUFamilyApple7 = 1007,
    MTLGPUFamilyApple8 = 1008,
    MTLGPUFamilyApple9 = 1009,
    MTLGPUFamilyMac2 = 2002,
    MTLGPUFamilyCommon1 = 3001,
    MTLGPUFamilyCommon2 = 3002,
    MTLGPUFamilyCommon3 = 3003,
    MTLGPUFamilyMetal3 = 5001,
} MTLGPUFamily;

typedef enum {
    MTLCullModeNone = 0,
    MTLCullModeFront = 1,
    MTLCullModeBack = 2,
} MTLCullMode;

typedef enum {
    MTLWindingClockwise = 0,
    MTLWindingCounterClockwise = 1,
} MTLWinding;

typedef enum {
    MTLTriangleFillModeFill = 0,
    MTLTriangleFillModeLines = 1,
} MTLTriangleFillMode;

typedef enum {
    MTLStencilOperationKeep = 0,
    MTLStencilOperationZero = 1,
    MTLStencilOperationReplace = 2,
    MTLStencilOperationIncrementClamp = 3,
    MTLStencilOperationDecrementClamp = 4,
    MTLStencilOperationInvert = 5,
    MTLStencilOperationIncrementWrap = 6,
    MTLStencilOperationDecrementWrap = 7,
} MTLStencilOperation;

typedef enum {
    MTLHeapTypeAutomatic = 0,
    MTLHeapTypePlacement = 1,
    MTLHeapTypeSparse = 2,
} MTLHeapType;

typedef enum {
    MTLPurgeableStateKeepCurrent = 1,
    MTLPurgeableStateNonVolatile = 2,
    MTLPurgeableStateVolatile = 3,
    MTLPurgeableStateEmpty = 4,
} MTLPurgeableState;

// =============================================================================
// Global Functions
// =============================================================================

MTLDeviceRef MTLWrapperCreateSystemDefaultDevice(void);
NSArrayRef MTLWrapperCopyAllDevices(void);

// =============================================================================
// Autorelease Pool
// =============================================================================

AutoreleasePoolRef AutoreleasePoolCreate(void);
void AutoreleasePoolRelease(AutoreleasePoolRef pool);

// =============================================================================
// Memory Management
// =============================================================================

void Release(void* obj);
void Retain(void* obj);
uint64_t RetainCount(void* obj);

// =============================================================================
// NSError
// =============================================================================

const char* NSErrorLocalizedDescription(NSErrorRef error);
int64_t NSErrorCode(NSErrorRef error);
const char* NSErrorDomain(NSErrorRef error);

// =============================================================================
// NSArray
// =============================================================================

uint64_t NSArrayCount(NSArrayRef array);
void* NSArrayObjectAtIndex(NSArrayRef array, uint64_t index);

// =============================================================================
// MTLDevice
// =============================================================================

const char* MTLDeviceName(MTLDeviceRef device);
uint64_t MTLDeviceRegistryID(MTLDeviceRef device);
bool MTLDeviceHasUnifiedMemory(MTLDeviceRef device);
uint64_t MTLDeviceRecommendedMaxWorkingSetSize(MTLDeviceRef device);
uint64_t MTLDeviceMaxBufferLength(MTLDeviceRef device);
uint64_t MTLDeviceMaxThreadgroupMemoryLength(MTLDeviceRef device);
uint64_t MTLDeviceMaxThreadsPerThreadgroup(MTLDeviceRef device, MTLSize* size);
bool MTLDeviceSupportsFamily(MTLDeviceRef device, MTLGPUFamily family);
bool MTLDeviceSupportsTextureSampleCount(MTLDeviceRef device, uint64_t sampleCount);
uint64_t MTLDeviceCurrentAllocatedSize(MTLDeviceRef device);
bool MTLDeviceAreProgrammableSamplePositionsSupported(MTLDeviceRef device);
bool MTLDeviceAreRasterOrderGroupsSupported(MTLDeviceRef device);
bool MTLDeviceSupportsRaytracing(MTLDeviceRef device);
bool MTLDeviceSupportsShaderBarycentricCoordinates(MTLDeviceRef device);
bool MTLDeviceSupportsPrimitiveMotionBlur(MTLDeviceRef device);
bool MTLDeviceSupports32BitFloatFiltering(MTLDeviceRef device);
bool MTLDeviceSupports32BitMSAA(MTLDeviceRef device);
bool MTLDeviceSupportsBCTextureCompression(MTLDeviceRef device);
bool MTLDeviceSupportsPullModelInterpolation(MTLDeviceRef device);
bool MTLDeviceSupportsFunctionPointers(MTLDeviceRef device);
bool MTLDeviceSupportsFunctionPointersFromRender(MTLDeviceRef device);
bool MTLDeviceSupportsRaytracingFromRender(MTLDeviceRef device);
bool MTLDeviceSupportsDynamicLibraries(MTLDeviceRef device);
uint32_t MTLDeviceReadWriteTextureSupport(MTLDeviceRef device);
MTLSizeAndAlign MTLDeviceHeapBufferSizeAndAlign(MTLDeviceRef device, uint64_t length, MTLResourceOptions options);
MTLSizeAndAlign MTLDeviceHeapTextureSizeAndAlign(MTLDeviceRef device, MTLTextureDescriptorRef desc);
uint64_t MTLDeviceSparseTileSizeInBytes(MTLDeviceRef device);

// Device - Object Creation
MTLCommandQueueRef MTLDeviceNewCommandQueue(MTLDeviceRef device);
MTLCommandQueueRef MTLDeviceNewCommandQueueWithMaxCommandBufferCount(MTLDeviceRef device, uint64_t maxCount);
MTLBufferRef MTLDeviceNewBufferWithLength(MTLDeviceRef device, uint64_t length, MTLResourceOptions options);
MTLBufferRef MTLDeviceNewBufferWithBytes(MTLDeviceRef device, const void* bytes, uint64_t length, MTLResourceOptions options);
MTLBufferRef MTLDeviceNewBufferWithBytesNoCopy(MTLDeviceRef device, void* bytes, uint64_t length, MTLResourceOptions options);
MTLTextureRef MTLDeviceNewTextureWithDescriptor(MTLDeviceRef device, MTLTextureDescriptorRef descriptor);
MTLSamplerStateRef MTLDeviceNewSamplerStateWithDescriptor(MTLDeviceRef device, MTLSamplerDescriptorRef descriptor);
MTLLibraryRef MTLDeviceNewLibraryWithSource(MTLDeviceRef device, const char* source, MTLCompileOptionsRef options, NSErrorRef* error);
MTLLibraryRef MTLDeviceNewLibraryWithFile(MTLDeviceRef device, const char* filepath, NSErrorRef* error);
MTLLibraryRef MTLDeviceNewLibraryWithData(MTLDeviceRef device, const void* data, size_t size, NSErrorRef* error);
MTLLibraryRef MTLDeviceNewDefaultLibrary(MTLDeviceRef device);
MTLLibraryRef MTLDeviceNewDefaultLibraryWithBundle(MTLDeviceRef device, const char* bundlePath, NSErrorRef* error);
MTLComputePipelineStateRef MTLDeviceNewComputePipelineStateWithFunction(MTLDeviceRef device, MTLFunctionRef function, NSErrorRef* error);
MTLComputePipelineStateRef MTLDeviceNewComputePipelineStateWithDescriptor(MTLDeviceRef device, MTLComputePipelineDescriptorRef descriptor, uint64_t options, void* reflection, NSErrorRef* error);
MTLRenderPipelineStateRef MTLDeviceNewRenderPipelineStateWithDescriptor(MTLDeviceRef device, MTLRenderPipelineDescriptorRef descriptor, NSErrorRef* error);
MTLDepthStencilStateRef MTLDeviceNewDepthStencilStateWithDescriptor(MTLDeviceRef device, MTLDepthStencilDescriptorRef descriptor);
MTLHeapRef MTLDeviceNewHeapWithDescriptor(MTLDeviceRef device, MTLHeapDescriptorRef descriptor);
MTLFenceRef MTLDeviceNewFence(MTLDeviceRef device);
MTLEventRef MTLDeviceNewEvent(MTLDeviceRef device);
MTLSharedEventRef MTLDeviceNewSharedEvent(MTLDeviceRef device);
MTLIndirectCommandBufferRef MTLDeviceNewIndirectCommandBufferWithDescriptor(MTLDeviceRef device, MTLIndirectCommandBufferDescriptorRef descriptor, uint64_t maxCount, MTLResourceOptions options);
MTLArgumentEncoderRef MTLDeviceNewArgumentEncoderWithArguments(MTLDeviceRef device, void* arguments, uint64_t count);
MTLBinaryArchiveRef MTLDeviceNewBinaryArchiveWithDescriptor(MTLDeviceRef device, void* descriptor, NSErrorRef* error);
MTLDynamicLibraryRef MTLDeviceNewDynamicLibrary(MTLDeviceRef device, MTLLibraryRef library, NSErrorRef* error);
MTLDynamicLibraryRef MTLDeviceNewDynamicLibraryWithURL(MTLDeviceRef device, const char* url, NSErrorRef* error);

// =============================================================================
// MTLCommandQueue
// =============================================================================

MTLCommandBufferRef MTLCommandQueueCommandBuffer(MTLCommandQueueRef queue);
MTLCommandBufferRef MTLCommandQueueCommandBufferWithUnretainedReferences(MTLCommandQueueRef queue);
const char* MTLCommandQueueLabel(MTLCommandQueueRef queue);
void MTLCommandQueueSetLabel(MTLCommandQueueRef queue, const char* label);
MTLDeviceRef MTLCommandQueueDevice(MTLCommandQueueRef queue);

// =============================================================================
// MTLCommandBuffer
// =============================================================================

void MTLCommandBufferEnqueue(MTLCommandBufferRef buffer);
void MTLCommandBufferCommit(MTLCommandBufferRef buffer);
void MTLCommandBufferWaitUntilScheduled(MTLCommandBufferRef buffer);
void MTLCommandBufferWaitUntilCompleted(MTLCommandBufferRef buffer);
MTLCommandBufferStatus MTLCommandBufferGetStatus(MTLCommandBufferRef buffer);
NSErrorRef MTLCommandBufferError(MTLCommandBufferRef buffer);
double MTLCommandBufferKernelStartTime(MTLCommandBufferRef buffer);
double MTLCommandBufferKernelEndTime(MTLCommandBufferRef buffer);
double MTLCommandBufferGPUStartTime(MTLCommandBufferRef buffer);
double MTLCommandBufferGPUEndTime(MTLCommandBufferRef buffer);
const char* MTLCommandBufferLabel(MTLCommandBufferRef buffer);
void MTLCommandBufferSetLabel(MTLCommandBufferRef buffer, const char* label);
MTLDeviceRef MTLCommandBufferDevice(MTLCommandBufferRef buffer);
MTLCommandQueueRef MTLCommandBufferCommandQueue(MTLCommandBufferRef buffer);
bool MTLCommandBufferRetainedReferences(MTLCommandBufferRef buffer);
void MTLCommandBufferPresentDrawable(MTLCommandBufferRef buffer, void* drawable);
void MTLCommandBufferEncodeSignalEvent(MTLCommandBufferRef buffer, MTLEventRef event, uint64_t value);
void MTLCommandBufferEncodeWaitForEvent(MTLCommandBufferRef buffer, MTLEventRef event, uint64_t value);

// CommandBuffer - Encoder Creation
MTLComputeCommandEncoderRef MTLCommandBufferComputeCommandEncoder(MTLCommandBufferRef buffer);
MTLComputeCommandEncoderRef MTLCommandBufferComputeCommandEncoderWithDispatchType(MTLCommandBufferRef buffer, MTLDispatchType type);
MTLBlitCommandEncoderRef MTLCommandBufferBlitCommandEncoder(MTLCommandBufferRef buffer);
MTLRenderCommandEncoderRef MTLCommandBufferRenderCommandEncoderWithDescriptor(MTLCommandBufferRef buffer, MTLRenderPassDescriptorRef descriptor);
MTLParallelRenderCommandEncoderRef MTLCommandBufferParallelRenderCommandEncoderWithDescriptor(MTLCommandBufferRef buffer, MTLRenderPassDescriptorRef descriptor);
MTLAccelerationStructureCommandEncoderRef MTLCommandBufferAccelerationStructureCommandEncoder(MTLCommandBufferRef buffer);
MTLResourceStateCommandEncoderRef MTLCommandBufferResourceStateCommandEncoder(MTLCommandBufferRef buffer);

// =============================================================================
// MTLBuffer
// =============================================================================

uint64_t MTLBufferLength(MTLBufferRef buffer);
void* MTLBufferContents(MTLBufferRef buffer);
uint64_t MTLBufferGPUAddress(MTLBufferRef buffer);
void MTLBufferDidModifyRange(MTLBufferRef buffer, uint64_t offset, uint64_t length);
MTLTextureRef MTLBufferNewTextureWithDescriptor(MTLBufferRef buffer, MTLTextureDescriptorRef descriptor, uint64_t offset, uint64_t bytesPerRow);
void MTLBufferAddDebugMarker(MTLBufferRef buffer, const char* marker, uint64_t offset, uint64_t length);
void MTLBufferRemoveAllDebugMarkers(MTLBufferRef buffer);
MTLDeviceRef MTLBufferDevice(MTLBufferRef buffer);
const char* MTLBufferLabel(MTLBufferRef buffer);
void MTLBufferSetLabel(MTLBufferRef buffer, const char* label);
MTLResourceOptions MTLBufferResourceOptions(MTLBufferRef buffer);
MTLStorageMode MTLBufferStorageMode(MTLBufferRef buffer);
MTLCPUCacheMode MTLBufferCPUCacheMode(MTLBufferRef buffer);
MTLHazardTrackingMode MTLBufferHazardTrackingMode(MTLBufferRef buffer);
MTLPurgeableState MTLBufferSetPurgeableState(MTLBufferRef buffer, MTLPurgeableState state);
MTLHeapRef MTLBufferHeap(MTLBufferRef buffer);
uint64_t MTLBufferHeapOffset(MTLBufferRef buffer);
uint64_t MTLBufferAllocatedSize(MTLBufferRef buffer);
bool MTLBufferIsAliasable(MTLBufferRef buffer);
void MTLBufferMakeAliasable(MTLBufferRef buffer);

// =============================================================================
// MTLTexture
// =============================================================================

uint64_t MTLTextureWidth(MTLTextureRef texture);
uint64_t MTLTextureHeight(MTLTextureRef texture);
uint64_t MTLTextureDepth(MTLTextureRef texture);
uint64_t MTLTextureMipmapLevelCount(MTLTextureRef texture);
uint64_t MTLTextureArrayLength(MTLTextureRef texture);
uint64_t MTLTextureSampleCount(MTLTextureRef texture);
MTLTextureType MTLTextureTextureType(MTLTextureRef texture);
MTLPixelFormat MTLTexturePixelFormat(MTLTextureRef texture);
MTLTextureUsage MTLTextureGetUsage(MTLTextureRef texture);
bool MTLTextureIsFramebufferOnly(MTLTextureRef texture);
bool MTLTextureAllowGPUOptimizedContents(MTLTextureRef texture);
bool MTLTextureIsShareable(MTLTextureRef texture);
MTLTextureRef MTLTextureParentTexture(MTLTextureRef texture);
uint64_t MTLTextureParentRelativeLevel(MTLTextureRef texture);
uint64_t MTLTextureParentRelativeSlice(MTLTextureRef texture);
MTLBufferRef MTLTextureBuffer(MTLTextureRef texture);
uint64_t MTLTextureBufferOffset(MTLTextureRef texture);
uint64_t MTLTextureBufferBytesPerRow(MTLTextureRef texture);
void MTLTextureReplaceRegion(MTLTextureRef texture, MTLRegion region, uint64_t level, uint64_t slice, const void* bytes, uint64_t bytesPerRow, uint64_t bytesPerImage);
void MTLTextureGetBytes(MTLTextureRef texture, void* bytes, uint64_t bytesPerRow, uint64_t bytesPerImage, MTLRegion region, uint64_t level, uint64_t slice);
MTLTextureRef MTLTextureNewTextureViewWithPixelFormat(MTLTextureRef texture, MTLPixelFormat format);
MTLTextureRef MTLTextureNewTextureViewWithPixelFormatAndType(MTLTextureRef texture, MTLPixelFormat format, MTLTextureType type, uint64_t levelStart, uint64_t levelCount, uint64_t sliceStart, uint64_t sliceCount);
MTLDeviceRef MTLTextureDevice(MTLTextureRef texture);
const char* MTLTextureLabel(MTLTextureRef texture);
void MTLTextureSetLabel(MTLTextureRef texture, const char* label);
MTLResourceOptions MTLTextureResourceOptions(MTLTextureRef texture);
MTLStorageMode MTLTextureStorageMode(MTLTextureRef texture);
MTLCPUCacheMode MTLTextureCPUCacheMode(MTLTextureRef texture);
MTLHazardTrackingMode MTLTextureHazardTrackingMode(MTLTextureRef texture);
MTLPurgeableState MTLTextureSetPurgeableState(MTLTextureRef texture, MTLPurgeableState state);
MTLHeapRef MTLTextureHeap(MTLTextureRef texture);
uint64_t MTLTextureHeapOffset(MTLTextureRef texture);
uint64_t MTLTextureAllocatedSize(MTLTextureRef texture);
bool MTLTextureIsAliasable(MTLTextureRef texture);
void MTLTextureMakeAliasable(MTLTextureRef texture);

// =============================================================================
// MTLLibrary
// =============================================================================

MTLFunctionRef MTLLibraryNewFunctionWithName(MTLLibraryRef library, const char* name);
NSArrayRef MTLLibraryFunctionNames(MTLLibraryRef library);
MTLDeviceRef MTLLibraryDevice(MTLLibraryRef library);
const char* MTLLibraryLabel(MTLLibraryRef library);
void MTLLibrarySetLabel(MTLLibraryRef library, const char* label);

// =============================================================================
// MTLFunction
// =============================================================================

const char* MTLFunctionName(MTLFunctionRef function);
uint64_t MTLFunctionFunctionType(MTLFunctionRef function);
MTLDeviceRef MTLFunctionDevice(MTLFunctionRef function);
const char* MTLFunctionLabel(MTLFunctionRef function);
void MTLFunctionSetLabel(MTLFunctionRef function, const char* label);

// =============================================================================
// MTLComputePipelineState
// =============================================================================

uint64_t MTLComputePipelineStateMaxTotalThreadsPerThreadgroup(MTLComputePipelineStateRef pipeline);
uint64_t MTLComputePipelineStateThreadExecutionWidth(MTLComputePipelineStateRef pipeline);
uint64_t MTLComputePipelineStateStaticThreadgroupMemoryLength(MTLComputePipelineStateRef pipeline);
MTLDeviceRef MTLComputePipelineStateDevice(MTLComputePipelineStateRef pipeline);
const char* MTLComputePipelineStateLabel(MTLComputePipelineStateRef pipeline);
bool MTLComputePipelineStateSupportIndirectCommandBuffers(MTLComputePipelineStateRef pipeline);

// =============================================================================
// MTLRenderPipelineState
// =============================================================================

MTLDeviceRef MTLRenderPipelineStateDevice(MTLRenderPipelineStateRef pipeline);
const char* MTLRenderPipelineStateLabel(MTLRenderPipelineStateRef pipeline);
uint64_t MTLRenderPipelineStateMaxTotalThreadsPerThreadgroup(MTLRenderPipelineStateRef pipeline);
bool MTLRenderPipelineStateSupportIndirectCommandBuffers(MTLRenderPipelineStateRef pipeline);

// =============================================================================
// MTLDepthStencilState
// =============================================================================

MTLDeviceRef MTLDepthStencilStateDevice(MTLDepthStencilStateRef state);
const char* MTLDepthStencilStateLabel(MTLDepthStencilStateRef state);

// =============================================================================
// MTLComputeCommandEncoder
// =============================================================================

void MTLComputeCommandEncoderSetComputePipelineState(MTLComputeCommandEncoderRef encoder, MTLComputePipelineStateRef pipeline);
void MTLComputeCommandEncoderSetBuffer(MTLComputeCommandEncoderRef encoder, MTLBufferRef buffer, uint64_t offset, uint64_t index);
void MTLComputeCommandEncoderSetBufferOffset(MTLComputeCommandEncoderRef encoder, uint64_t offset, uint64_t index);
void MTLComputeCommandEncoderSetBytes(MTLComputeCommandEncoderRef encoder, const void* bytes, uint64_t length, uint64_t index);
void MTLComputeCommandEncoderSetTexture(MTLComputeCommandEncoderRef encoder, MTLTextureRef texture, uint64_t index);
void MTLComputeCommandEncoderSetSamplerState(MTLComputeCommandEncoderRef encoder, MTLSamplerStateRef sampler, uint64_t index);
void MTLComputeCommandEncoderSetSamplerStateWithLod(MTLComputeCommandEncoderRef encoder, MTLSamplerStateRef sampler, float lodMinClamp, float lodMaxClamp, uint64_t index);
void MTLComputeCommandEncoderSetThreadgroupMemoryLength(MTLComputeCommandEncoderRef encoder, uint64_t length, uint64_t index);
void MTLComputeCommandEncoderDispatchThreadgroups(MTLComputeCommandEncoderRef encoder, MTLSize threadgroupsPerGrid, MTLSize threadsPerThreadgroup);
void MTLComputeCommandEncoderDispatchThreads(MTLComputeCommandEncoderRef encoder, MTLSize threadsPerGrid, MTLSize threadsPerThreadgroup);
void MTLComputeCommandEncoderDispatchThreadgroupsWithIndirectBuffer(MTLComputeCommandEncoderRef encoder, MTLBufferRef indirectBuffer, uint64_t offset, MTLSize threadsPerThreadgroup);
void MTLComputeCommandEncoderUseResource(MTLComputeCommandEncoderRef encoder, void* resource, MTLResourceUsage usage);
void MTLComputeCommandEncoderUseResources(MTLComputeCommandEncoderRef encoder, void** resources, uint64_t count, MTLResourceUsage usage);
void MTLComputeCommandEncoderUseHeap(MTLComputeCommandEncoderRef encoder, MTLHeapRef heap);
void MTLComputeCommandEncoderUseHeaps(MTLComputeCommandEncoderRef encoder, MTLHeapRef* heaps, uint64_t count);
void MTLComputeCommandEncoderMemoryBarrierWithScope(MTLComputeCommandEncoderRef encoder, MTLBarrierScope scope);
void MTLComputeCommandEncoderMemoryBarrierWithResources(MTLComputeCommandEncoderRef encoder, void** resources, uint64_t count);
void MTLComputeCommandEncoderSetStageInRegion(MTLComputeCommandEncoderRef encoder, MTLRegion region);
void MTLComputeCommandEncoderSetImageblockWidth(MTLComputeCommandEncoderRef encoder, uint64_t width, uint64_t height);
void MTLComputeCommandEncoderUpdateFence(MTLComputeCommandEncoderRef encoder, MTLFenceRef fence);
void MTLComputeCommandEncoderWaitForFence(MTLComputeCommandEncoderRef encoder, MTLFenceRef fence);
void MTLComputeCommandEncoderEndEncoding(MTLComputeCommandEncoderRef encoder);
void MTLComputeCommandEncoderInsertDebugSignpost(MTLComputeCommandEncoderRef encoder, const char* string);
void MTLComputeCommandEncoderPushDebugGroup(MTLComputeCommandEncoderRef encoder, const char* string);
void MTLComputeCommandEncoderPopDebugGroup(MTLComputeCommandEncoderRef encoder);
MTLDeviceRef MTLComputeCommandEncoderDevice(MTLComputeCommandEncoderRef encoder);
const char* MTLComputeCommandEncoderLabel(MTLComputeCommandEncoderRef encoder);
void MTLComputeCommandEncoderSetLabel(MTLComputeCommandEncoderRef encoder, const char* label);

// =============================================================================
// MTLBlitCommandEncoder
// =============================================================================

void MTLBlitCommandEncoderCopyFromBuffer(MTLBlitCommandEncoderRef encoder, MTLBufferRef srcBuffer, uint64_t srcOffset, MTLBufferRef dstBuffer, uint64_t dstOffset, uint64_t size);
void MTLBlitCommandEncoderCopyFromTexture(MTLBlitCommandEncoderRef encoder, MTLTextureRef srcTexture, uint64_t srcSlice, uint64_t srcLevel, MTLOrigin srcOrigin, MTLSize srcSize, MTLTextureRef dstTexture, uint64_t dstSlice, uint64_t dstLevel, MTLOrigin dstOrigin);
void MTLBlitCommandEncoderCopyFromBufferToTexture(MTLBlitCommandEncoderRef encoder, MTLBufferRef srcBuffer, uint64_t srcOffset, uint64_t srcBytesPerRow, uint64_t srcBytesPerImage, MTLSize srcSize, MTLTextureRef dstTexture, uint64_t dstSlice, uint64_t dstLevel, MTLOrigin dstOrigin);
void MTLBlitCommandEncoderCopyFromTextureToBuffer(MTLBlitCommandEncoderRef encoder, MTLTextureRef srcTexture, uint64_t srcSlice, uint64_t srcLevel, MTLOrigin srcOrigin, MTLSize srcSize, MTLBufferRef dstBuffer, uint64_t dstOffset, uint64_t dstBytesPerRow, uint64_t dstBytesPerImage);
void MTLBlitCommandEncoderFillBuffer(MTLBlitCommandEncoderRef encoder, MTLBufferRef buffer, uint64_t offset, uint64_t length, uint8_t value);
void MTLBlitCommandEncoderGenerateMipmapsForTexture(MTLBlitCommandEncoderRef encoder, MTLTextureRef texture);
void MTLBlitCommandEncoderSynchronizeResource(MTLBlitCommandEncoderRef encoder, void* resource);
void MTLBlitCommandEncoderSynchronizeTexture(MTLBlitCommandEncoderRef encoder, MTLTextureRef texture, uint64_t slice, uint64_t level);
void MTLBlitCommandEncoderOptimizeContentsForGPUAccess(MTLBlitCommandEncoderRef encoder, MTLTextureRef texture);
void MTLBlitCommandEncoderOptimizeContentsForGPUAccessWithSlice(MTLBlitCommandEncoderRef encoder, MTLTextureRef texture, uint64_t slice, uint64_t level);
void MTLBlitCommandEncoderOptimizeContentsForCPUAccess(MTLBlitCommandEncoderRef encoder, MTLTextureRef texture);
void MTLBlitCommandEncoderOptimizeContentsForCPUAccessWithSlice(MTLBlitCommandEncoderRef encoder, MTLTextureRef texture, uint64_t slice, uint64_t level);
void MTLBlitCommandEncoderUpdateFence(MTLBlitCommandEncoderRef encoder, MTLFenceRef fence);
void MTLBlitCommandEncoderWaitForFence(MTLBlitCommandEncoderRef encoder, MTLFenceRef fence);
void MTLBlitCommandEncoderEndEncoding(MTLBlitCommandEncoderRef encoder);
void MTLBlitCommandEncoderInsertDebugSignpost(MTLBlitCommandEncoderRef encoder, const char* string);
void MTLBlitCommandEncoderPushDebugGroup(MTLBlitCommandEncoderRef encoder, const char* string);
void MTLBlitCommandEncoderPopDebugGroup(MTLBlitCommandEncoderRef encoder);
MTLDeviceRef MTLBlitCommandEncoderDevice(MTLBlitCommandEncoderRef encoder);
const char* MTLBlitCommandEncoderLabel(MTLBlitCommandEncoderRef encoder);
void MTLBlitCommandEncoderSetLabel(MTLBlitCommandEncoderRef encoder, const char* label);

// =============================================================================
// MTLRenderCommandEncoder (Core)
// =============================================================================

void MTLRenderCommandEncoderSetRenderPipelineState(MTLRenderCommandEncoderRef encoder, MTLRenderPipelineStateRef pipeline);
void MTLRenderCommandEncoderSetVertexBuffer(MTLRenderCommandEncoderRef encoder, MTLBufferRef buffer, uint64_t offset, uint64_t index);
void MTLRenderCommandEncoderSetVertexBufferOffset(MTLRenderCommandEncoderRef encoder, uint64_t offset, uint64_t index);
void MTLRenderCommandEncoderSetVertexBytes(MTLRenderCommandEncoderRef encoder, const void* bytes, uint64_t length, uint64_t index);
void MTLRenderCommandEncoderSetVertexTexture(MTLRenderCommandEncoderRef encoder, MTLTextureRef texture, uint64_t index);
void MTLRenderCommandEncoderSetVertexSamplerState(MTLRenderCommandEncoderRef encoder, MTLSamplerStateRef sampler, uint64_t index);
void MTLRenderCommandEncoderSetFragmentBuffer(MTLRenderCommandEncoderRef encoder, MTLBufferRef buffer, uint64_t offset, uint64_t index);
void MTLRenderCommandEncoderSetFragmentBufferOffset(MTLRenderCommandEncoderRef encoder, uint64_t offset, uint64_t index);
void MTLRenderCommandEncoderSetFragmentBytes(MTLRenderCommandEncoderRef encoder, const void* bytes, uint64_t length, uint64_t index);
void MTLRenderCommandEncoderSetFragmentTexture(MTLRenderCommandEncoderRef encoder, MTLTextureRef texture, uint64_t index);
void MTLRenderCommandEncoderSetFragmentSamplerState(MTLRenderCommandEncoderRef encoder, MTLSamplerStateRef sampler, uint64_t index);
void MTLRenderCommandEncoderSetDepthStencilState(MTLRenderCommandEncoderRef encoder, MTLDepthStencilStateRef state);
void MTLRenderCommandEncoderSetCullMode(MTLRenderCommandEncoderRef encoder, MTLCullMode mode);
void MTLRenderCommandEncoderSetFrontFacingWinding(MTLRenderCommandEncoderRef encoder, MTLWinding winding);
void MTLRenderCommandEncoderSetTriangleFillMode(MTLRenderCommandEncoderRef encoder, MTLTriangleFillMode mode);
void MTLRenderCommandEncoderSetDepthBias(MTLRenderCommandEncoderRef encoder, float depthBias, float slopeScale, float clamp);
void MTLRenderCommandEncoderSetDepthClipMode(MTLRenderCommandEncoderRef encoder, uint64_t mode);
void MTLRenderCommandEncoderSetScissorRect(MTLRenderCommandEncoderRef encoder, MTLScissorRect rect);
void MTLRenderCommandEncoderSetViewport(MTLRenderCommandEncoderRef encoder, double originX, double originY, double width, double height, double znear, double zfar);
void MTLRenderCommandEncoderSetStencilReferenceValue(MTLRenderCommandEncoderRef encoder, uint32_t value);
void MTLRenderCommandEncoderSetStencilReferenceValues(MTLRenderCommandEncoderRef encoder, uint32_t front, uint32_t back);
void MTLRenderCommandEncoderSetBlendColor(MTLRenderCommandEncoderRef encoder, float red, float green, float blue, float alpha);
void MTLRenderCommandEncoderSetVisibilityResultMode(MTLRenderCommandEncoderRef encoder, uint64_t mode, uint64_t offset);
void MTLRenderCommandEncoderDrawPrimitives(MTLRenderCommandEncoderRef encoder, MTLPrimitiveType type, uint64_t vertexStart, uint64_t vertexCount);
void MTLRenderCommandEncoderDrawPrimitivesInstanced(MTLRenderCommandEncoderRef encoder, MTLPrimitiveType type, uint64_t vertexStart, uint64_t vertexCount, uint64_t instanceCount);
void MTLRenderCommandEncoderDrawPrimitivesInstancedWithBaseInstance(MTLRenderCommandEncoderRef encoder, MTLPrimitiveType type, uint64_t vertexStart, uint64_t vertexCount, uint64_t instanceCount, uint64_t baseInstance);
void MTLRenderCommandEncoderDrawIndexedPrimitives(MTLRenderCommandEncoderRef encoder, MTLPrimitiveType type, uint64_t indexCount, MTLIndexType indexType, MTLBufferRef indexBuffer, uint64_t indexBufferOffset);
void MTLRenderCommandEncoderDrawIndexedPrimitivesInstanced(MTLRenderCommandEncoderRef encoder, MTLPrimitiveType type, uint64_t indexCount, MTLIndexType indexType, MTLBufferRef indexBuffer, uint64_t indexBufferOffset, uint64_t instanceCount);
void MTLRenderCommandEncoderDrawIndexedPrimitivesInstancedWithBaseVertex(MTLRenderCommandEncoderRef encoder, MTLPrimitiveType type, uint64_t indexCount, MTLIndexType indexType, MTLBufferRef indexBuffer, uint64_t indexBufferOffset, uint64_t instanceCount, int64_t baseVertex, uint64_t baseInstance);
void MTLRenderCommandEncoderDrawPrimitivesIndirect(MTLRenderCommandEncoderRef encoder, MTLPrimitiveType type, MTLBufferRef indirectBuffer, uint64_t offset);
void MTLRenderCommandEncoderDrawIndexedPrimitivesIndirect(MTLRenderCommandEncoderRef encoder, MTLPrimitiveType type, MTLIndexType indexType, MTLBufferRef indexBuffer, uint64_t indexBufferOffset, MTLBufferRef indirectBuffer, uint64_t indirectOffset);
void MTLRenderCommandEncoderUseResource(MTLRenderCommandEncoderRef encoder, void* resource, MTLResourceUsage usage);
void MTLRenderCommandEncoderUseResources(MTLRenderCommandEncoderRef encoder, void** resources, uint64_t count, MTLResourceUsage usage);
void MTLRenderCommandEncoderUseHeap(MTLRenderCommandEncoderRef encoder, MTLHeapRef heap);
void MTLRenderCommandEncoderUseHeaps(MTLRenderCommandEncoderRef encoder, MTLHeapRef* heaps, uint64_t count);
void MTLRenderCommandEncoderUpdateFence(MTLRenderCommandEncoderRef encoder, MTLFenceRef fence, uint64_t stages);
void MTLRenderCommandEncoderWaitForFence(MTLRenderCommandEncoderRef encoder, MTLFenceRef fence, uint64_t stages);
void MTLRenderCommandEncoderEndEncoding(MTLRenderCommandEncoderRef encoder);
void MTLRenderCommandEncoderInsertDebugSignpost(MTLRenderCommandEncoderRef encoder, const char* string);
void MTLRenderCommandEncoderPushDebugGroup(MTLRenderCommandEncoderRef encoder, const char* string);
void MTLRenderCommandEncoderPopDebugGroup(MTLRenderCommandEncoderRef encoder);
MTLDeviceRef MTLRenderCommandEncoderDevice(MTLRenderCommandEncoderRef encoder);
const char* MTLRenderCommandEncoderLabel(MTLRenderCommandEncoderRef encoder);
void MTLRenderCommandEncoderSetLabel(MTLRenderCommandEncoderRef encoder, const char* label);

// =============================================================================
// MTLHeap
// =============================================================================

uint64_t MTLHeapSize(MTLHeapRef heap);
uint64_t MTLHeapUsedSize(MTLHeapRef heap);
uint64_t MTLHeapCurrentAllocatedSize(MTLHeapRef heap);
uint64_t MTLHeapMaxAvailableSizeWithAlignment(MTLHeapRef heap, uint64_t alignment);
MTLHeapType MTLHeapGetType(MTLHeapRef heap);
MTLStorageMode MTLHeapStorageMode(MTLHeapRef heap);
MTLCPUCacheMode MTLHeapCPUCacheMode(MTLHeapRef heap);
MTLHazardTrackingMode MTLHeapHazardTrackingMode(MTLHeapRef heap);
MTLResourceOptions MTLHeapResourceOptions(MTLHeapRef heap);
MTLPurgeableState MTLHeapSetPurgeableState(MTLHeapRef heap, MTLPurgeableState state);
MTLBufferRef MTLHeapNewBufferWithLength(MTLHeapRef heap, uint64_t length, MTLResourceOptions options);
MTLBufferRef MTLHeapNewBufferWithLengthAndOffset(MTLHeapRef heap, uint64_t length, MTLResourceOptions options, uint64_t offset);
MTLTextureRef MTLHeapNewTextureWithDescriptor(MTLHeapRef heap, MTLTextureDescriptorRef descriptor);
MTLTextureRef MTLHeapNewTextureWithDescriptorAndOffset(MTLHeapRef heap, MTLTextureDescriptorRef descriptor, uint64_t offset);
MTLDeviceRef MTLHeapDevice(MTLHeapRef heap);
const char* MTLHeapLabel(MTLHeapRef heap);
void MTLHeapSetLabel(MTLHeapRef heap, const char* label);

// =============================================================================
// MTLEvent / MTLSharedEvent
// =============================================================================

MTLDeviceRef MTLEventDevice(MTLEventRef event);
const char* MTLEventLabel(MTLEventRef event);
void MTLEventSetLabel(MTLEventRef event, const char* label);
uint64_t MTLSharedEventSignaledValue(MTLSharedEventRef event);
void MTLSharedEventSetSignaledValue(MTLSharedEventRef event, uint64_t value);

// =============================================================================
// MTLFence
// =============================================================================

MTLDeviceRef MTLFenceDevice(MTLFenceRef fence);
const char* MTLFenceLabel(MTLFenceRef fence);
void MTLFenceSetLabel(MTLFenceRef fence, const char* label);

// =============================================================================
// Descriptors
// =============================================================================

// MTLTextureDescriptor
MTLTextureDescriptorRef MTLTextureDescriptorCreate(void);
void MTLTextureDescriptorSetTextureType(MTLTextureDescriptorRef desc, MTLTextureType type);
void MTLTextureDescriptorSetPixelFormat(MTLTextureDescriptorRef desc, MTLPixelFormat format);
void MTLTextureDescriptorSetWidth(MTLTextureDescriptorRef desc, uint64_t width);
void MTLTextureDescriptorSetHeight(MTLTextureDescriptorRef desc, uint64_t height);
void MTLTextureDescriptorSetDepth(MTLTextureDescriptorRef desc, uint64_t depth);
void MTLTextureDescriptorSetMipmapLevelCount(MTLTextureDescriptorRef desc, uint64_t count);
void MTLTextureDescriptorSetArrayLength(MTLTextureDescriptorRef desc, uint64_t length);
void MTLTextureDescriptorSetSampleCount(MTLTextureDescriptorRef desc, uint64_t count);
void MTLTextureDescriptorSetStorageMode(MTLTextureDescriptorRef desc, MTLStorageMode mode);
void MTLTextureDescriptorSetCPUCacheMode(MTLTextureDescriptorRef desc, MTLCPUCacheMode mode);
void MTLTextureDescriptorSetUsage(MTLTextureDescriptorRef desc, MTLTextureUsage usage);
void MTLTextureDescriptorSetResourceOptions(MTLTextureDescriptorRef desc, MTLResourceOptions options);
void MTLTextureDescriptorSetAllowGPUOptimizedContents(MTLTextureDescriptorRef desc, bool allow);
void MTLTextureDescriptorSetHazardTrackingMode(MTLTextureDescriptorRef desc, MTLHazardTrackingMode mode);
MTLTextureDescriptorRef MTLTextureDescriptorTexture2DDescriptor(MTLPixelFormat format, uint64_t width, uint64_t height, bool mipmapped);
MTLTextureDescriptorRef MTLTextureDescriptorTextureCubeDescriptor(MTLPixelFormat format, uint64_t size, bool mipmapped);
MTLTextureDescriptorRef MTLTextureDescriptorTextureBufferDescriptor(MTLPixelFormat format, uint64_t width, MTLResourceOptions options, MTLTextureUsage usage);

// MTLSamplerDescriptor
MTLSamplerDescriptorRef MTLSamplerDescriptorCreate(void);
void MTLSamplerDescriptorSetMinFilter(MTLSamplerDescriptorRef desc, MTLSamplerMinMagFilter filter);
void MTLSamplerDescriptorSetMagFilter(MTLSamplerDescriptorRef desc, MTLSamplerMinMagFilter filter);
void MTLSamplerDescriptorSetMipFilter(MTLSamplerDescriptorRef desc, MTLSamplerMipFilter filter);
void MTLSamplerDescriptorSetSAddressMode(MTLSamplerDescriptorRef desc, MTLSamplerAddressMode mode);
void MTLSamplerDescriptorSetTAddressMode(MTLSamplerDescriptorRef desc, MTLSamplerAddressMode mode);
void MTLSamplerDescriptorSetRAddressMode(MTLSamplerDescriptorRef desc, MTLSamplerAddressMode mode);
void MTLSamplerDescriptorSetMaxAnisotropy(MTLSamplerDescriptorRef desc, uint64_t value);
void MTLSamplerDescriptorSetCompareFunction(MTLSamplerDescriptorRef desc, MTLCompareFunction func);
void MTLSamplerDescriptorSetLodMinClamp(MTLSamplerDescriptorRef desc, float value);
void MTLSamplerDescriptorSetLodMaxClamp(MTLSamplerDescriptorRef desc, float value);
void MTLSamplerDescriptorSetNormalizedCoordinates(MTLSamplerDescriptorRef desc, bool normalized);
void MTLSamplerDescriptorSetSupportArgumentBuffers(MTLSamplerDescriptorRef desc, bool support);
void MTLSamplerDescriptorSetLabel(MTLSamplerDescriptorRef desc, const char* label);

// MTLDepthStencilDescriptor
MTLDepthStencilDescriptorRef MTLDepthStencilDescriptorCreate(void);
void MTLDepthStencilDescriptorSetDepthCompareFunction(MTLDepthStencilDescriptorRef desc, MTLCompareFunction func);
void MTLDepthStencilDescriptorSetDepthWriteEnabled(MTLDepthStencilDescriptorRef desc, bool enabled);
void MTLDepthStencilDescriptorSetFrontFaceStencil(MTLDepthStencilDescriptorRef desc, MTLStencilDescriptorRef stencil);
void MTLDepthStencilDescriptorSetBackFaceStencil(MTLDepthStencilDescriptorRef desc, MTLStencilDescriptorRef stencil);
void MTLDepthStencilDescriptorSetLabel(MTLDepthStencilDescriptorRef desc, const char* label);

// MTLStencilDescriptor
MTLStencilDescriptorRef MTLStencilDescriptorCreate(void);
void MTLStencilDescriptorSetStencilCompareFunction(MTLStencilDescriptorRef desc, MTLCompareFunction func);
void MTLStencilDescriptorSetStencilFailureOperation(MTLStencilDescriptorRef desc, MTLStencilOperation op);
void MTLStencilDescriptorSetDepthFailureOperation(MTLStencilDescriptorRef desc, MTLStencilOperation op);
void MTLStencilDescriptorSetDepthStencilPassOperation(MTLStencilDescriptorRef desc, MTLStencilOperation op);
void MTLStencilDescriptorSetReadMask(MTLStencilDescriptorRef desc, uint32_t mask);
void MTLStencilDescriptorSetWriteMask(MTLStencilDescriptorRef desc, uint32_t mask);

// MTLRenderPassDescriptor
MTLRenderPassDescriptorRef MTLRenderPassDescriptorCreate(void);
void MTLRenderPassDescriptorSetColorAttachmentTexture(MTLRenderPassDescriptorRef desc, uint64_t index, MTLTextureRef texture);
void MTLRenderPassDescriptorSetColorAttachmentLoadAction(MTLRenderPassDescriptorRef desc, uint64_t index, MTLLoadAction action);
void MTLRenderPassDescriptorSetColorAttachmentStoreAction(MTLRenderPassDescriptorRef desc, uint64_t index, MTLStoreAction action);
void MTLRenderPassDescriptorSetColorAttachmentClearColor(MTLRenderPassDescriptorRef desc, uint64_t index, MTLClearColor color);
void MTLRenderPassDescriptorSetDepthAttachmentTexture(MTLRenderPassDescriptorRef desc, MTLTextureRef texture);
void MTLRenderPassDescriptorSetDepthAttachmentLoadAction(MTLRenderPassDescriptorRef desc, MTLLoadAction action);
void MTLRenderPassDescriptorSetDepthAttachmentStoreAction(MTLRenderPassDescriptorRef desc, MTLStoreAction action);
void MTLRenderPassDescriptorSetDepthAttachmentClearDepth(MTLRenderPassDescriptorRef desc, double depth);
void MTLRenderPassDescriptorSetStencilAttachmentTexture(MTLRenderPassDescriptorRef desc, MTLTextureRef texture);
void MTLRenderPassDescriptorSetStencilAttachmentLoadAction(MTLRenderPassDescriptorRef desc, MTLLoadAction action);
void MTLRenderPassDescriptorSetStencilAttachmentStoreAction(MTLRenderPassDescriptorRef desc, MTLStoreAction action);
void MTLRenderPassDescriptorSetStencilAttachmentClearStencil(MTLRenderPassDescriptorRef desc, uint32_t stencil);
void MTLRenderPassDescriptorSetRenderTargetWidth(MTLRenderPassDescriptorRef desc, uint64_t width);
void MTLRenderPassDescriptorSetRenderTargetHeight(MTLRenderPassDescriptorRef desc, uint64_t height);
void MTLRenderPassDescriptorSetRenderTargetArrayLength(MTLRenderPassDescriptorRef desc, uint64_t length);

// MTLHeapDescriptor
MTLHeapDescriptorRef MTLHeapDescriptorCreate(void);
void MTLHeapDescriptorSetSize(MTLHeapDescriptorRef desc, uint64_t size);
void MTLHeapDescriptorSetStorageMode(MTLHeapDescriptorRef desc, MTLStorageMode mode);
void MTLHeapDescriptorSetCPUCacheMode(MTLHeapDescriptorRef desc, MTLCPUCacheMode mode);
void MTLHeapDescriptorSetHazardTrackingMode(MTLHeapDescriptorRef desc, MTLHazardTrackingMode mode);
void MTLHeapDescriptorSetResourceOptions(MTLHeapDescriptorRef desc, MTLResourceOptions options);
void MTLHeapDescriptorSetType(MTLHeapDescriptorRef desc, MTLHeapType type);

// MTLRenderPipelineDescriptor
MTLRenderPipelineDescriptorRef MTLRenderPipelineDescriptorCreate(void);
void MTLRenderPipelineDescriptorSetVertexFunction(MTLRenderPipelineDescriptorRef desc, MTLFunctionRef function);
void MTLRenderPipelineDescriptorSetFragmentFunction(MTLRenderPipelineDescriptorRef desc, MTLFunctionRef function);
void MTLRenderPipelineDescriptorSetVertexDescriptor(MTLRenderPipelineDescriptorRef desc, MTLVertexDescriptorRef vertexDesc);
void MTLRenderPipelineDescriptorSetColorAttachmentPixelFormat(MTLRenderPipelineDescriptorRef desc, uint64_t index, MTLPixelFormat format);
void MTLRenderPipelineDescriptorSetColorAttachmentBlendingEnabled(MTLRenderPipelineDescriptorRef desc, uint64_t index, bool enabled);
void MTLRenderPipelineDescriptorSetColorAttachmentSourceRGBBlendFactor(MTLRenderPipelineDescriptorRef desc, uint64_t index, MTLBlendFactor factor);
void MTLRenderPipelineDescriptorSetColorAttachmentDestinationRGBBlendFactor(MTLRenderPipelineDescriptorRef desc, uint64_t index, MTLBlendFactor factor);
void MTLRenderPipelineDescriptorSetColorAttachmentSourceAlphaBlendFactor(MTLRenderPipelineDescriptorRef desc, uint64_t index, MTLBlendFactor factor);
void MTLRenderPipelineDescriptorSetColorAttachmentDestinationAlphaBlendFactor(MTLRenderPipelineDescriptorRef desc, uint64_t index, MTLBlendFactor factor);
void MTLRenderPipelineDescriptorSetColorAttachmentRGBBlendOperation(MTLRenderPipelineDescriptorRef desc, uint64_t index, MTLBlendOperation op);
void MTLRenderPipelineDescriptorSetColorAttachmentAlphaBlendOperation(MTLRenderPipelineDescriptorRef desc, uint64_t index, MTLBlendOperation op);
void MTLRenderPipelineDescriptorSetColorAttachmentWriteMask(MTLRenderPipelineDescriptorRef desc, uint64_t index, uint64_t mask);
void MTLRenderPipelineDescriptorSetDepthAttachmentPixelFormat(MTLRenderPipelineDescriptorRef desc, MTLPixelFormat format);
void MTLRenderPipelineDescriptorSetStencilAttachmentPixelFormat(MTLRenderPipelineDescriptorRef desc, MTLPixelFormat format);
void MTLRenderPipelineDescriptorSetSampleCount(MTLRenderPipelineDescriptorRef desc, uint64_t count);
void MTLRenderPipelineDescriptorSetAlphaToCoverageEnabled(MTLRenderPipelineDescriptorRef desc, bool enabled);
void MTLRenderPipelineDescriptorSetAlphaToOneEnabled(MTLRenderPipelineDescriptorRef desc, bool enabled);
void MTLRenderPipelineDescriptorSetRasterizationEnabled(MTLRenderPipelineDescriptorRef desc, bool enabled);
void MTLRenderPipelineDescriptorSetInputPrimitiveTopology(MTLRenderPipelineDescriptorRef desc, uint64_t topology);
void MTLRenderPipelineDescriptorSetLabel(MTLRenderPipelineDescriptorRef desc, const char* label);

// MTLComputePipelineDescriptor
MTLComputePipelineDescriptorRef MTLComputePipelineDescriptorCreate(void);
void MTLComputePipelineDescriptorSetComputeFunction(MTLComputePipelineDescriptorRef desc, MTLFunctionRef function);
void MTLComputePipelineDescriptorSetThreadGroupSizeIsMultipleOfThreadExecutionWidth(MTLComputePipelineDescriptorRef desc, bool value);
void MTLComputePipelineDescriptorSetMaxTotalThreadsPerThreadgroup(MTLComputePipelineDescriptorRef desc, uint64_t count);
void MTLComputePipelineDescriptorSetMaxCallStackDepth(MTLComputePipelineDescriptorRef desc, uint64_t depth);
void MTLComputePipelineDescriptorSetSupportIndirectCommandBuffers(MTLComputePipelineDescriptorRef desc, bool support);
void MTLComputePipelineDescriptorSetLabel(MTLComputePipelineDescriptorRef desc, const char* label);

// MTLCompileOptions
MTLCompileOptionsRef MTLCompileOptionsCreate(void);
void MTLCompileOptionsSetFastMathEnabled(MTLCompileOptionsRef options, bool enabled);
void MTLCompileOptionsSetLanguageVersion(MTLCompileOptionsRef options, uint64_t version);
void MTLCompileOptionsSetPreserveInvariance(MTLCompileOptionsRef options, bool preserve);

// MTLVertexDescriptor
MTLVertexDescriptorRef MTLVertexDescriptorCreate(void);
void MTLVertexDescriptorSetAttributeFormat(MTLVertexDescriptorRef desc, uint64_t index, MTLVertexFormat format);
void MTLVertexDescriptorSetAttributeOffset(MTLVertexDescriptorRef desc, uint64_t index, uint64_t offset);
void MTLVertexDescriptorSetAttributeBufferIndex(MTLVertexDescriptorRef desc, uint64_t index, uint64_t bufferIndex);
void MTLVertexDescriptorSetLayoutStride(MTLVertexDescriptorRef desc, uint64_t index, uint64_t stride);
void MTLVertexDescriptorSetLayoutStepFunction(MTLVertexDescriptorRef desc, uint64_t index, MTLVertexStepFunction stepFunc);
void MTLVertexDescriptorSetLayoutStepRate(MTLVertexDescriptorRef desc, uint64_t index, uint64_t stepRate);

#ifdef __cplusplus
}
#endif

#endif // METAL_WRAPPER_H
