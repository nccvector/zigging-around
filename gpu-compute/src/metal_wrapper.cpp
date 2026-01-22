// metal_wrapper.cpp - C wrapper implementation for metal-cpp
// Define implementation macros BEFORE including headers (required for metal-cpp)

#define NS_PRIVATE_IMPLEMENTATION
#define CA_PRIVATE_IMPLEMENTATION
#define MTL_PRIVATE_IMPLEMENTATION

#include <Foundation/Foundation.hpp>
#include <Metal/Metal.hpp>
#include <QuartzCore/QuartzCore.hpp>

#include "metal_wrapper.h"

// =============================================================================
// Global Functions
// =============================================================================

extern "C" {

MTLDeviceRef MTLWrapperCreateSystemDefaultDevice(void) {
    return MTL::CreateSystemDefaultDevice();
}

NSArrayRef MTLWrapperCopyAllDevices(void) {
    return MTL::CopyAllDevices();
}

// =============================================================================
// Autorelease Pool
// =============================================================================

AutoreleasePoolRef AutoreleasePoolCreate(void) {
    return NS::AutoreleasePool::alloc()->init();
}

void AutoreleasePoolRelease(AutoreleasePoolRef pool) {
    if (pool) static_cast<NS::AutoreleasePool*>(pool)->release();
}

// =============================================================================
// Memory Management
// =============================================================================

void Release(void* obj) {
    if (obj) static_cast<NS::Object*>(obj)->release();
}

void Retain(void* obj) {
    if (obj) static_cast<NS::Object*>(obj)->retain();
}

uint64_t RetainCount(void* obj) {
    return obj ? static_cast<NS::Object*>(obj)->retainCount() : 0;
}

// =============================================================================
// NSError
// =============================================================================

const char* NSErrorLocalizedDescription(NSErrorRef error) {
    if (!error) return nullptr;
    auto* desc = static_cast<NS::Error*>(error)->localizedDescription();
    return desc ? desc->utf8String() : nullptr;
}

int64_t NSErrorCode(NSErrorRef error) {
    return error ? static_cast<NS::Error*>(error)->code() : 0;
}

const char* NSErrorDomain(NSErrorRef error) {
    if (!error) return nullptr;
    auto* domain = static_cast<NS::Error*>(error)->domain();
    return domain ? domain->utf8String() : nullptr;
}

// =============================================================================
// NSArray
// =============================================================================

uint64_t NSArrayCount(NSArrayRef array) {
    return array ? static_cast<NS::Array*>(array)->count() : 0;
}

void* NSArrayObjectAtIndex(NSArrayRef array, uint64_t index) {
    return array ? static_cast<NS::Array*>(array)->object(index) : nullptr;
}

// =============================================================================
// MTLDevice - Properties
// =============================================================================

const char* MTLDeviceName(MTLDeviceRef device) {
    if (!device) return nullptr;
    auto* name = static_cast<MTL::Device*>(device)->name();
    return name ? name->utf8String() : nullptr;
}

uint64_t MTLDeviceRegistryID(MTLDeviceRef device) {
    return device ? static_cast<MTL::Device*>(device)->registryID() : 0;
}

bool MTLDeviceHasUnifiedMemory(MTLDeviceRef device) {
    return device ? static_cast<MTL::Device*>(device)->hasUnifiedMemory() : false;
}

uint64_t MTLDeviceRecommendedMaxWorkingSetSize(MTLDeviceRef device) {
    return device ? static_cast<MTL::Device*>(device)->recommendedMaxWorkingSetSize() : 0;
}

uint64_t MTLDeviceMaxBufferLength(MTLDeviceRef device) {
    return device ? static_cast<MTL::Device*>(device)->maxBufferLength() : 0;
}

uint64_t MTLDeviceMaxThreadgroupMemoryLength(MTLDeviceRef device) {
    return device ? static_cast<MTL::Device*>(device)->maxThreadgroupMemoryLength() : 0;
}

uint64_t MTLDeviceMaxThreadsPerThreadgroup(MTLDeviceRef device, MTLSize* size) {
    if (!device) return 0;
    auto mtlSize = static_cast<MTL::Device*>(device)->maxThreadsPerThreadgroup();
    if (size) {
        size->width = mtlSize.width;
        size->height = mtlSize.height;
        size->depth = mtlSize.depth;
    }
    return mtlSize.width * mtlSize.height * mtlSize.depth;
}

bool MTLDeviceSupportsFamily(MTLDeviceRef device, MTLGPUFamily family) {
    return device ? static_cast<MTL::Device*>(device)->supportsFamily(static_cast<MTL::GPUFamily>(family)) : false;
}

bool MTLDeviceSupportsTextureSampleCount(MTLDeviceRef device, uint64_t sampleCount) {
    return device ? static_cast<MTL::Device*>(device)->supportsTextureSampleCount(sampleCount) : false;
}

uint64_t MTLDeviceCurrentAllocatedSize(MTLDeviceRef device) {
    return device ? static_cast<MTL::Device*>(device)->currentAllocatedSize() : 0;
}

bool MTLDeviceAreProgrammableSamplePositionsSupported(MTLDeviceRef device) {
    // Not available in all metal-cpp versions, return false as fallback
    return false;
}

bool MTLDeviceAreRasterOrderGroupsSupported(MTLDeviceRef device) {
    // Not available in all metal-cpp versions, return false as fallback
    return false;
}

bool MTLDeviceSupportsRaytracing(MTLDeviceRef device) {
    return device ? static_cast<MTL::Device*>(device)->supportsRaytracing() : false;
}

bool MTLDeviceSupportsShaderBarycentricCoordinates(MTLDeviceRef device) {
    return device ? static_cast<MTL::Device*>(device)->supportsShaderBarycentricCoordinates() : false;
}

bool MTLDeviceSupportsPrimitiveMotionBlur(MTLDeviceRef device) {
    return device ? static_cast<MTL::Device*>(device)->supportsPrimitiveMotionBlur() : false;
}

bool MTLDeviceSupports32BitFloatFiltering(MTLDeviceRef device) {
    return device ? static_cast<MTL::Device*>(device)->supports32BitFloatFiltering() : false;
}

bool MTLDeviceSupports32BitMSAA(MTLDeviceRef device) {
    return device ? static_cast<MTL::Device*>(device)->supports32BitMSAA() : false;
}

bool MTLDeviceSupportsBCTextureCompression(MTLDeviceRef device) {
    return device ? static_cast<MTL::Device*>(device)->supportsBCTextureCompression() : false;
}

bool MTLDeviceSupportsPullModelInterpolation(MTLDeviceRef device) {
    return device ? static_cast<MTL::Device*>(device)->supportsPullModelInterpolation() : false;
}

bool MTLDeviceSupportsFunctionPointers(MTLDeviceRef device) {
    return device ? static_cast<MTL::Device*>(device)->supportsFunctionPointers() : false;
}

bool MTLDeviceSupportsFunctionPointersFromRender(MTLDeviceRef device) {
    return device ? static_cast<MTL::Device*>(device)->supportsFunctionPointersFromRender() : false;
}

bool MTLDeviceSupportsRaytracingFromRender(MTLDeviceRef device) {
    return device ? static_cast<MTL::Device*>(device)->supportsRaytracingFromRender() : false;
}

bool MTLDeviceSupportsDynamicLibraries(MTLDeviceRef device) {
    return device ? static_cast<MTL::Device*>(device)->supportsDynamicLibraries() : false;
}

uint32_t MTLDeviceReadWriteTextureSupport(MTLDeviceRef device) {
    return device ? static_cast<uint32_t>(static_cast<MTL::Device*>(device)->readWriteTextureSupport()) : 0;
}

MTLSizeAndAlign MTLDeviceHeapBufferSizeAndAlign(MTLDeviceRef device, uint64_t length, MTLResourceOptions options) {
    MTLSizeAndAlign result = {0, 0};
    if (device) {
        auto sa = static_cast<MTL::Device*>(device)->heapBufferSizeAndAlign(length, static_cast<MTL::ResourceOptions>(options));
        result.size = sa.size;
        result.align = sa.align;
    }
    return result;
}

MTLSizeAndAlign MTLDeviceHeapTextureSizeAndAlign(MTLDeviceRef device, MTLTextureDescriptorRef desc) {
    MTLSizeAndAlign result = {0, 0};
    if (device && desc) {
        auto sa = static_cast<MTL::Device*>(device)->heapTextureSizeAndAlign(static_cast<MTL::TextureDescriptor*>(desc));
        result.size = sa.size;
        result.align = sa.align;
    }
    return result;
}

uint64_t MTLDeviceSparseTileSizeInBytes(MTLDeviceRef device) {
    return device ? static_cast<MTL::Device*>(device)->sparseTileSizeInBytes() : 0;
}

// =============================================================================
// MTLDevice - Object Creation
// =============================================================================

MTLCommandQueueRef MTLDeviceNewCommandQueue(MTLDeviceRef device) {
    return device ? static_cast<MTL::Device*>(device)->newCommandQueue() : nullptr;
}

MTLCommandQueueRef MTLDeviceNewCommandQueueWithMaxCommandBufferCount(MTLDeviceRef device, uint64_t maxCount) {
    return device ? static_cast<MTL::Device*>(device)->newCommandQueue(maxCount) : nullptr;
}

MTLBufferRef MTLDeviceNewBufferWithLength(MTLDeviceRef device, uint64_t length, MTLResourceOptions options) {
    return device ? static_cast<MTL::Device*>(device)->newBuffer(length, static_cast<MTL::ResourceOptions>(options)) : nullptr;
}

MTLBufferRef MTLDeviceNewBufferWithBytes(MTLDeviceRef device, const void* bytes, uint64_t length, MTLResourceOptions options) {
    return device ? static_cast<MTL::Device*>(device)->newBuffer(bytes, length, static_cast<MTL::ResourceOptions>(options)) : nullptr;
}

MTLBufferRef MTLDeviceNewBufferWithBytesNoCopy(MTLDeviceRef device, void* bytes, uint64_t length, MTLResourceOptions options) {
    return device ? static_cast<MTL::Device*>(device)->newBuffer(bytes, length, static_cast<MTL::ResourceOptions>(options), nullptr) : nullptr;
}

MTLTextureRef MTLDeviceNewTextureWithDescriptor(MTLDeviceRef device, MTLTextureDescriptorRef descriptor) {
    return (device && descriptor) ? static_cast<MTL::Device*>(device)->newTexture(static_cast<MTL::TextureDescriptor*>(descriptor)) : nullptr;
}

MTLSamplerStateRef MTLDeviceNewSamplerStateWithDescriptor(MTLDeviceRef device, MTLSamplerDescriptorRef descriptor) {
    return (device && descriptor) ? static_cast<MTL::Device*>(device)->newSamplerState(static_cast<MTL::SamplerDescriptor*>(descriptor)) : nullptr;
}

MTLLibraryRef MTLDeviceNewLibraryWithSource(MTLDeviceRef device, const char* source, MTLCompileOptionsRef options, NSErrorRef* error) {
    if (!device || !source) return nullptr;
    NS::Error* nsError = nullptr;
    auto* nsSource = NS::String::string(source, NS::UTF8StringEncoding);
    auto* library = static_cast<MTL::Device*>(device)->newLibrary(nsSource, static_cast<MTL::CompileOptions*>(options), &nsError);
    if (error) *error = nsError;
    return library;
}

MTLLibraryRef MTLDeviceNewLibraryWithFile(MTLDeviceRef device, const char* filepath, NSErrorRef* error) {
    if (!device || !filepath) return nullptr;
    NS::Error* nsError = nullptr;
    auto* nsPath = NS::String::string(filepath, NS::UTF8StringEncoding);
    auto* library = static_cast<MTL::Device*>(device)->newLibrary(nsPath, &nsError);
    if (error) *error = nsError;
    return library;
}

MTLLibraryRef MTLDeviceNewLibraryWithData(MTLDeviceRef device, const void* data, size_t size, NSErrorRef* error) {
    if (!device || !data) return nullptr;
    NS::Error* nsError = nullptr;
    auto* dispatchData = dispatch_data_create(data, size, nullptr, DISPATCH_DATA_DESTRUCTOR_DEFAULT);
    auto* library = static_cast<MTL::Device*>(device)->newLibrary(dispatchData, &nsError);
    dispatch_release(dispatchData);
    if (error) *error = nsError;
    return library;
}

MTLLibraryRef MTLDeviceNewDefaultLibrary(MTLDeviceRef device) {
    return device ? static_cast<MTL::Device*>(device)->newDefaultLibrary() : nullptr;
}

MTLLibraryRef MTLDeviceNewDefaultLibraryWithBundle(MTLDeviceRef device, const char* bundlePath, NSErrorRef* error) {
    if (!device || !bundlePath) return nullptr;
    NS::Error* nsError = nullptr;
    auto* nsPath = NS::String::string(bundlePath, NS::UTF8StringEncoding);
    auto* bundle = NS::Bundle::alloc()->init(nsPath);
    auto* library = static_cast<MTL::Device*>(device)->newDefaultLibrary(bundle, &nsError);
    if (error) *error = nsError;
    return library;
}

MTLComputePipelineStateRef MTLDeviceNewComputePipelineStateWithFunction(MTLDeviceRef device, MTLFunctionRef function, NSErrorRef* error) {
    if (!device || !function) return nullptr;
    NS::Error* nsError = nullptr;
    auto* pipeline = static_cast<MTL::Device*>(device)->newComputePipelineState(static_cast<MTL::Function*>(function), &nsError);
    if (error) *error = nsError;
    return pipeline;
}

MTLComputePipelineStateRef MTLDeviceNewComputePipelineStateWithDescriptor(MTLDeviceRef device, MTLComputePipelineDescriptorRef descriptor, uint64_t options, void* reflection, NSErrorRef* error) {
    if (!device || !descriptor) return nullptr;
    NS::Error* nsError = nullptr;
    auto* pipeline = static_cast<MTL::Device*>(device)->newComputePipelineState(
        static_cast<MTL::ComputePipelineDescriptor*>(descriptor),
        static_cast<MTL::PipelineOption>(options),
        static_cast<MTL::AutoreleasedComputePipelineReflection*>(reflection),
        &nsError
    );
    if (error) *error = nsError;
    return pipeline;
}

MTLRenderPipelineStateRef MTLDeviceNewRenderPipelineStateWithDescriptor(MTLDeviceRef device, MTLRenderPipelineDescriptorRef descriptor, NSErrorRef* error) {
    if (!device || !descriptor) return nullptr;
    NS::Error* nsError = nullptr;
    auto* pipeline = static_cast<MTL::Device*>(device)->newRenderPipelineState(static_cast<MTL::RenderPipelineDescriptor*>(descriptor), &nsError);
    if (error) *error = nsError;
    return pipeline;
}

MTLDepthStencilStateRef MTLDeviceNewDepthStencilStateWithDescriptor(MTLDeviceRef device, MTLDepthStencilDescriptorRef descriptor) {
    return (device && descriptor) ? static_cast<MTL::Device*>(device)->newDepthStencilState(static_cast<MTL::DepthStencilDescriptor*>(descriptor)) : nullptr;
}

MTLHeapRef MTLDeviceNewHeapWithDescriptor(MTLDeviceRef device, MTLHeapDescriptorRef descriptor) {
    return (device && descriptor) ? static_cast<MTL::Device*>(device)->newHeap(static_cast<MTL::HeapDescriptor*>(descriptor)) : nullptr;
}

MTLFenceRef MTLDeviceNewFence(MTLDeviceRef device) {
    return device ? static_cast<MTL::Device*>(device)->newFence() : nullptr;
}

MTLEventRef MTLDeviceNewEvent(MTLDeviceRef device) {
    return device ? static_cast<MTL::Device*>(device)->newEvent() : nullptr;
}

MTLSharedEventRef MTLDeviceNewSharedEvent(MTLDeviceRef device) {
    return device ? static_cast<MTL::Device*>(device)->newSharedEvent() : nullptr;
}

MTLIndirectCommandBufferRef MTLDeviceNewIndirectCommandBufferWithDescriptor(MTLDeviceRef device, MTLIndirectCommandBufferDescriptorRef descriptor, uint64_t maxCount, MTLResourceOptions options) {
    return (device && descriptor) ? static_cast<MTL::Device*>(device)->newIndirectCommandBuffer(static_cast<MTL::IndirectCommandBufferDescriptor*>(descriptor), maxCount, static_cast<MTL::ResourceOptions>(options)) : nullptr;
}

MTLArgumentEncoderRef MTLDeviceNewArgumentEncoderWithArguments(MTLDeviceRef device, void* arguments, uint64_t count) {
    // Note: This requires proper MTLArgumentDescriptor array handling
    return nullptr; // Placeholder - needs proper implementation with argument descriptors
}

MTLBinaryArchiveRef MTLDeviceNewBinaryArchiveWithDescriptor(MTLDeviceRef device, void* descriptor, NSErrorRef* error) {
    if (!device) return nullptr;
    NS::Error* nsError = nullptr;
    auto* archive = static_cast<MTL::Device*>(device)->newBinaryArchive(static_cast<MTL::BinaryArchiveDescriptor*>(descriptor), &nsError);
    if (error) *error = nsError;
    return archive;
}

MTLDynamicLibraryRef MTLDeviceNewDynamicLibrary(MTLDeviceRef device, MTLLibraryRef library, NSErrorRef* error) {
    if (!device || !library) return nullptr;
    NS::Error* nsError = nullptr;
    auto* dynLib = static_cast<MTL::Device*>(device)->newDynamicLibrary(static_cast<MTL::Library*>(library), &nsError);
    if (error) *error = nsError;
    return dynLib;
}

MTLDynamicLibraryRef MTLDeviceNewDynamicLibraryWithURL(MTLDeviceRef device, const char* url, NSErrorRef* error) {
    if (!device || !url) return nullptr;
    NS::Error* nsError = nullptr;
    auto* nsUrl = NS::URL::fileURLWithPath(NS::String::string(url, NS::UTF8StringEncoding));
    auto* dynLib = static_cast<MTL::Device*>(device)->newDynamicLibrary(nsUrl, &nsError);
    if (error) *error = nsError;
    return dynLib;
}

// =============================================================================
// MTLCommandQueue
// =============================================================================

MTLCommandBufferRef MTLCommandQueueCommandBuffer(MTLCommandQueueRef queue) {
    return queue ? static_cast<MTL::CommandQueue*>(queue)->commandBuffer() : nullptr;
}

MTLCommandBufferRef MTLCommandQueueCommandBufferWithUnretainedReferences(MTLCommandQueueRef queue) {
    return queue ? static_cast<MTL::CommandQueue*>(queue)->commandBufferWithUnretainedReferences() : nullptr;
}

const char* MTLCommandQueueLabel(MTLCommandQueueRef queue) {
    if (!queue) return nullptr;
    auto* label = static_cast<MTL::CommandQueue*>(queue)->label();
    return label ? label->utf8String() : nullptr;
}

void MTLCommandQueueSetLabel(MTLCommandQueueRef queue, const char* label) {
    if (queue && label) {
        static_cast<MTL::CommandQueue*>(queue)->setLabel(NS::String::string(label, NS::UTF8StringEncoding));
    }
}

MTLDeviceRef MTLCommandQueueDevice(MTLCommandQueueRef queue) {
    return queue ? static_cast<MTL::CommandQueue*>(queue)->device() : nullptr;
}

// =============================================================================
// MTLCommandBuffer
// =============================================================================

void MTLCommandBufferEnqueue(MTLCommandBufferRef buffer) {
    if (buffer) static_cast<MTL::CommandBuffer*>(buffer)->enqueue();
}

void MTLCommandBufferCommit(MTLCommandBufferRef buffer) {
    if (buffer) static_cast<MTL::CommandBuffer*>(buffer)->commit();
}

void MTLCommandBufferWaitUntilScheduled(MTLCommandBufferRef buffer) {
    if (buffer) static_cast<MTL::CommandBuffer*>(buffer)->waitUntilScheduled();
}

void MTLCommandBufferWaitUntilCompleted(MTLCommandBufferRef buffer) {
    if (buffer) static_cast<MTL::CommandBuffer*>(buffer)->waitUntilCompleted();
}

MTLCommandBufferStatus MTLCommandBufferGetStatus(MTLCommandBufferRef buffer) {
    return buffer ? static_cast<MTLCommandBufferStatus>(static_cast<MTL::CommandBuffer*>(buffer)->status()) : MTLCommandBufferStatusNotEnqueued;
}

NSErrorRef MTLCommandBufferError(MTLCommandBufferRef buffer) {
    return buffer ? static_cast<MTL::CommandBuffer*>(buffer)->error() : nullptr;
}

double MTLCommandBufferKernelStartTime(MTLCommandBufferRef buffer) {
    return buffer ? static_cast<MTL::CommandBuffer*>(buffer)->kernelStartTime() : 0.0;
}

double MTLCommandBufferKernelEndTime(MTLCommandBufferRef buffer) {
    return buffer ? static_cast<MTL::CommandBuffer*>(buffer)->kernelEndTime() : 0.0;
}

double MTLCommandBufferGPUStartTime(MTLCommandBufferRef buffer) {
    return buffer ? static_cast<MTL::CommandBuffer*>(buffer)->GPUStartTime() : 0.0;
}

double MTLCommandBufferGPUEndTime(MTLCommandBufferRef buffer) {
    return buffer ? static_cast<MTL::CommandBuffer*>(buffer)->GPUEndTime() : 0.0;
}

const char* MTLCommandBufferLabel(MTLCommandBufferRef buffer) {
    if (!buffer) return nullptr;
    auto* label = static_cast<MTL::CommandBuffer*>(buffer)->label();
    return label ? label->utf8String() : nullptr;
}

void MTLCommandBufferSetLabel(MTLCommandBufferRef buffer, const char* label) {
    if (buffer && label) {
        static_cast<MTL::CommandBuffer*>(buffer)->setLabel(NS::String::string(label, NS::UTF8StringEncoding));
    }
}

MTLDeviceRef MTLCommandBufferDevice(MTLCommandBufferRef buffer) {
    return buffer ? static_cast<MTL::CommandBuffer*>(buffer)->device() : nullptr;
}

MTLCommandQueueRef MTLCommandBufferCommandQueue(MTLCommandBufferRef buffer) {
    return buffer ? static_cast<MTL::CommandBuffer*>(buffer)->commandQueue() : nullptr;
}

bool MTLCommandBufferRetainedReferences(MTLCommandBufferRef buffer) {
    return buffer ? static_cast<MTL::CommandBuffer*>(buffer)->retainedReferences() : false;
}

void MTLCommandBufferPresentDrawable(MTLCommandBufferRef buffer, void* drawable) {
    if (buffer && drawable) {
        static_cast<MTL::CommandBuffer*>(buffer)->presentDrawable(static_cast<MTL::Drawable*>(drawable));
    }
}

void MTLCommandBufferEncodeSignalEvent(MTLCommandBufferRef buffer, MTLEventRef event, uint64_t value) {
    if (buffer && event) {
        static_cast<MTL::CommandBuffer*>(buffer)->encodeSignalEvent(static_cast<MTL::Event*>(event), value);
    }
}

void MTLCommandBufferEncodeWaitForEvent(MTLCommandBufferRef buffer, MTLEventRef event, uint64_t value) {
    if (buffer && event) {
        static_cast<MTL::CommandBuffer*>(buffer)->encodeWait(static_cast<MTL::Event*>(event), value);
    }
}

// CommandBuffer - Encoder Creation
MTLComputeCommandEncoderRef MTLCommandBufferComputeCommandEncoder(MTLCommandBufferRef buffer) {
    return buffer ? static_cast<MTL::CommandBuffer*>(buffer)->computeCommandEncoder() : nullptr;
}

MTLComputeCommandEncoderRef MTLCommandBufferComputeCommandEncoderWithDispatchType(MTLCommandBufferRef buffer, MTLDispatchType type) {
    return buffer ? static_cast<MTL::CommandBuffer*>(buffer)->computeCommandEncoder(static_cast<MTL::DispatchType>(type)) : nullptr;
}

MTLBlitCommandEncoderRef MTLCommandBufferBlitCommandEncoder(MTLCommandBufferRef buffer) {
    return buffer ? static_cast<MTL::CommandBuffer*>(buffer)->blitCommandEncoder() : nullptr;
}

MTLRenderCommandEncoderRef MTLCommandBufferRenderCommandEncoderWithDescriptor(MTLCommandBufferRef buffer, MTLRenderPassDescriptorRef descriptor) {
    return (buffer && descriptor) ? static_cast<MTL::CommandBuffer*>(buffer)->renderCommandEncoder(static_cast<MTL::RenderPassDescriptor*>(descriptor)) : nullptr;
}

MTLParallelRenderCommandEncoderRef MTLCommandBufferParallelRenderCommandEncoderWithDescriptor(MTLCommandBufferRef buffer, MTLRenderPassDescriptorRef descriptor) {
    return (buffer && descriptor) ? static_cast<MTL::CommandBuffer*>(buffer)->parallelRenderCommandEncoder(static_cast<MTL::RenderPassDescriptor*>(descriptor)) : nullptr;
}

MTLAccelerationStructureCommandEncoderRef MTLCommandBufferAccelerationStructureCommandEncoder(MTLCommandBufferRef buffer) {
    return buffer ? static_cast<MTL::CommandBuffer*>(buffer)->accelerationStructureCommandEncoder() : nullptr;
}

MTLResourceStateCommandEncoderRef MTLCommandBufferResourceStateCommandEncoder(MTLCommandBufferRef buffer) {
    return buffer ? static_cast<MTL::CommandBuffer*>(buffer)->resourceStateCommandEncoder() : nullptr;
}

// =============================================================================
// MTLBuffer
// =============================================================================

uint64_t MTLBufferLength(MTLBufferRef buffer) {
    return buffer ? static_cast<MTL::Buffer*>(buffer)->length() : 0;
}

void* MTLBufferContents(MTLBufferRef buffer) {
    return buffer ? static_cast<MTL::Buffer*>(buffer)->contents() : nullptr;
}

uint64_t MTLBufferGPUAddress(MTLBufferRef buffer) {
    // gpuAddress() not available in all metal-cpp versions
    // Return 0 as fallback - this feature requires macOS 13+ / iOS 16+
    return 0;
}

void MTLBufferDidModifyRange(MTLBufferRef buffer, uint64_t offset, uint64_t length) {
    if (buffer) {
        static_cast<MTL::Buffer*>(buffer)->didModifyRange(NS::Range::Make(offset, length));
    }
}

MTLTextureRef MTLBufferNewTextureWithDescriptor(MTLBufferRef buffer, MTLTextureDescriptorRef descriptor, uint64_t offset, uint64_t bytesPerRow) {
    return (buffer && descriptor) ? static_cast<MTL::Buffer*>(buffer)->newTexture(static_cast<MTL::TextureDescriptor*>(descriptor), offset, bytesPerRow) : nullptr;
}

void MTLBufferAddDebugMarker(MTLBufferRef buffer, const char* marker, uint64_t offset, uint64_t length) {
    if (buffer && marker) {
        static_cast<MTL::Buffer*>(buffer)->addDebugMarker(NS::String::string(marker, NS::UTF8StringEncoding), NS::Range::Make(offset, length));
    }
}

void MTLBufferRemoveAllDebugMarkers(MTLBufferRef buffer) {
    if (buffer) static_cast<MTL::Buffer*>(buffer)->removeAllDebugMarkers();
}

MTLDeviceRef MTLBufferDevice(MTLBufferRef buffer) {
    return buffer ? static_cast<MTL::Buffer*>(buffer)->device() : nullptr;
}

const char* MTLBufferLabel(MTLBufferRef buffer) {
    if (!buffer) return nullptr;
    auto* label = static_cast<MTL::Buffer*>(buffer)->label();
    return label ? label->utf8String() : nullptr;
}

void MTLBufferSetLabel(MTLBufferRef buffer, const char* label) {
    if (buffer && label) {
        static_cast<MTL::Buffer*>(buffer)->setLabel(NS::String::string(label, NS::UTF8StringEncoding));
    }
}

MTLResourceOptions MTLBufferResourceOptions(MTLBufferRef buffer) {
    return buffer ? static_cast<MTL::Buffer*>(buffer)->resourceOptions() : 0;
}

MTLStorageMode MTLBufferStorageMode(MTLBufferRef buffer) {
    return buffer ? static_cast<MTLStorageMode>(static_cast<MTL::Buffer*>(buffer)->storageMode()) : MTLResourceStorageModeShared;
}

MTLCPUCacheMode MTLBufferCPUCacheMode(MTLBufferRef buffer) {
    return buffer ? static_cast<MTLCPUCacheMode>(static_cast<MTL::Buffer*>(buffer)->cpuCacheMode()) : MTLResourceCPUCacheModeDefaultCache;
}

MTLHazardTrackingMode MTLBufferHazardTrackingMode(MTLBufferRef buffer) {
    return buffer ? static_cast<MTLHazardTrackingMode>(static_cast<MTL::Buffer*>(buffer)->hazardTrackingMode()) : MTLResourceHazardTrackingModeDefault;
}

MTLPurgeableState MTLBufferSetPurgeableState(MTLBufferRef buffer, MTLPurgeableState state) {
    return buffer ? static_cast<MTLPurgeableState>(static_cast<MTL::Buffer*>(buffer)->setPurgeableState(static_cast<MTL::PurgeableState>(state))) : MTLPurgeableStateKeepCurrent;
}

MTLHeapRef MTLBufferHeap(MTLBufferRef buffer) {
    return buffer ? static_cast<MTL::Buffer*>(buffer)->heap() : nullptr;
}

uint64_t MTLBufferHeapOffset(MTLBufferRef buffer) {
    return buffer ? static_cast<MTL::Buffer*>(buffer)->heapOffset() : 0;
}

uint64_t MTLBufferAllocatedSize(MTLBufferRef buffer) {
    return buffer ? static_cast<MTL::Buffer*>(buffer)->allocatedSize() : 0;
}

bool MTLBufferIsAliasable(MTLBufferRef buffer) {
    return buffer ? static_cast<MTL::Buffer*>(buffer)->isAliasable() : false;
}

void MTLBufferMakeAliasable(MTLBufferRef buffer) {
    if (buffer) static_cast<MTL::Buffer*>(buffer)->makeAliasable();
}

// =============================================================================
// MTLLibrary
// =============================================================================

MTLFunctionRef MTLLibraryNewFunctionWithName(MTLLibraryRef library, const char* name) {
    if (!library || !name) return nullptr;
    return static_cast<MTL::Library*>(library)->newFunction(NS::String::string(name, NS::UTF8StringEncoding));
}

NSArrayRef MTLLibraryFunctionNames(MTLLibraryRef library) {
    return library ? static_cast<MTL::Library*>(library)->functionNames() : nullptr;
}

MTLDeviceRef MTLLibraryDevice(MTLLibraryRef library) {
    return library ? static_cast<MTL::Library*>(library)->device() : nullptr;
}

const char* MTLLibraryLabel(MTLLibraryRef library) {
    if (!library) return nullptr;
    auto* label = static_cast<MTL::Library*>(library)->label();
    return label ? label->utf8String() : nullptr;
}

void MTLLibrarySetLabel(MTLLibraryRef library, const char* label) {
    if (library && label) {
        static_cast<MTL::Library*>(library)->setLabel(NS::String::string(label, NS::UTF8StringEncoding));
    }
}

// =============================================================================
// MTLFunction
// =============================================================================

const char* MTLFunctionName(MTLFunctionRef function) {
    if (!function) return nullptr;
    auto* name = static_cast<MTL::Function*>(function)->name();
    return name ? name->utf8String() : nullptr;
}

uint64_t MTLFunctionFunctionType(MTLFunctionRef function) {
    return function ? static_cast<uint64_t>(static_cast<MTL::Function*>(function)->functionType()) : 0;
}

MTLDeviceRef MTLFunctionDevice(MTLFunctionRef function) {
    return function ? static_cast<MTL::Function*>(function)->device() : nullptr;
}

const char* MTLFunctionLabel(MTLFunctionRef function) {
    if (!function) return nullptr;
    auto* label = static_cast<MTL::Function*>(function)->label();
    return label ? label->utf8String() : nullptr;
}

void MTLFunctionSetLabel(MTLFunctionRef function, const char* label) {
    if (function && label) {
        static_cast<MTL::Function*>(function)->setLabel(NS::String::string(label, NS::UTF8StringEncoding));
    }
}

// =============================================================================
// MTLComputePipelineState
// =============================================================================

uint64_t MTLComputePipelineStateMaxTotalThreadsPerThreadgroup(MTLComputePipelineStateRef pipeline) {
    return pipeline ? static_cast<MTL::ComputePipelineState*>(pipeline)->maxTotalThreadsPerThreadgroup() : 0;
}

uint64_t MTLComputePipelineStateThreadExecutionWidth(MTLComputePipelineStateRef pipeline) {
    return pipeline ? static_cast<MTL::ComputePipelineState*>(pipeline)->threadExecutionWidth() : 0;
}

uint64_t MTLComputePipelineStateStaticThreadgroupMemoryLength(MTLComputePipelineStateRef pipeline) {
    return pipeline ? static_cast<MTL::ComputePipelineState*>(pipeline)->staticThreadgroupMemoryLength() : 0;
}

MTLDeviceRef MTLComputePipelineStateDevice(MTLComputePipelineStateRef pipeline) {
    return pipeline ? static_cast<MTL::ComputePipelineState*>(pipeline)->device() : nullptr;
}

const char* MTLComputePipelineStateLabel(MTLComputePipelineStateRef pipeline) {
    if (!pipeline) return nullptr;
    auto* label = static_cast<MTL::ComputePipelineState*>(pipeline)->label();
    return label ? label->utf8String() : nullptr;
}

bool MTLComputePipelineStateSupportIndirectCommandBuffers(MTLComputePipelineStateRef pipeline) {
    return pipeline ? static_cast<MTL::ComputePipelineState*>(pipeline)->supportIndirectCommandBuffers() : false;
}

// =============================================================================
// MTLRenderPipelineState
// =============================================================================

MTLDeviceRef MTLRenderPipelineStateDevice(MTLRenderPipelineStateRef pipeline) {
    return pipeline ? static_cast<MTL::RenderPipelineState*>(pipeline)->device() : nullptr;
}

const char* MTLRenderPipelineStateLabel(MTLRenderPipelineStateRef pipeline) {
    if (!pipeline) return nullptr;
    auto* label = static_cast<MTL::RenderPipelineState*>(pipeline)->label();
    return label ? label->utf8String() : nullptr;
}

uint64_t MTLRenderPipelineStateMaxTotalThreadsPerThreadgroup(MTLRenderPipelineStateRef pipeline) {
    return pipeline ? static_cast<MTL::RenderPipelineState*>(pipeline)->maxTotalThreadsPerThreadgroup() : 0;
}

bool MTLRenderPipelineStateSupportIndirectCommandBuffers(MTLRenderPipelineStateRef pipeline) {
    return pipeline ? static_cast<MTL::RenderPipelineState*>(pipeline)->supportIndirectCommandBuffers() : false;
}

// =============================================================================
// MTLDepthStencilState
// =============================================================================

MTLDeviceRef MTLDepthStencilStateDevice(MTLDepthStencilStateRef state) {
    return state ? static_cast<MTL::DepthStencilState*>(state)->device() : nullptr;
}

const char* MTLDepthStencilStateLabel(MTLDepthStencilStateRef state) {
    if (!state) return nullptr;
    auto* label = static_cast<MTL::DepthStencilState*>(state)->label();
    return label ? label->utf8String() : nullptr;
}

// =============================================================================
// MTLComputeCommandEncoder
// =============================================================================

void MTLComputeCommandEncoderSetComputePipelineState(MTLComputeCommandEncoderRef encoder, MTLComputePipelineStateRef pipeline) {
    if (encoder && pipeline) {
        static_cast<MTL::ComputeCommandEncoder*>(encoder)->setComputePipelineState(static_cast<MTL::ComputePipelineState*>(pipeline));
    }
}

void MTLComputeCommandEncoderSetBuffer(MTLComputeCommandEncoderRef encoder, MTLBufferRef buffer, uint64_t offset, uint64_t index) {
    if (encoder) {
        static_cast<MTL::ComputeCommandEncoder*>(encoder)->setBuffer(static_cast<MTL::Buffer*>(buffer), offset, index);
    }
}

void MTLComputeCommandEncoderSetBufferOffset(MTLComputeCommandEncoderRef encoder, uint64_t offset, uint64_t index) {
    if (encoder) {
        static_cast<MTL::ComputeCommandEncoder*>(encoder)->setBufferOffset(offset, index);
    }
}

void MTLComputeCommandEncoderSetBytes(MTLComputeCommandEncoderRef encoder, const void* bytes, uint64_t length, uint64_t index) {
    if (encoder && bytes) {
        static_cast<MTL::ComputeCommandEncoder*>(encoder)->setBytes(bytes, length, index);
    }
}

void MTLComputeCommandEncoderSetTexture(MTLComputeCommandEncoderRef encoder, MTLTextureRef texture, uint64_t index) {
    if (encoder) {
        static_cast<MTL::ComputeCommandEncoder*>(encoder)->setTexture(static_cast<MTL::Texture*>(texture), index);
    }
}

void MTLComputeCommandEncoderSetSamplerState(MTLComputeCommandEncoderRef encoder, MTLSamplerStateRef sampler, uint64_t index) {
    if (encoder) {
        static_cast<MTL::ComputeCommandEncoder*>(encoder)->setSamplerState(static_cast<MTL::SamplerState*>(sampler), index);
    }
}

void MTLComputeCommandEncoderSetSamplerStateWithLod(MTLComputeCommandEncoderRef encoder, MTLSamplerStateRef sampler, float lodMinClamp, float lodMaxClamp, uint64_t index) {
    if (encoder) {
        static_cast<MTL::ComputeCommandEncoder*>(encoder)->setSamplerState(static_cast<MTL::SamplerState*>(sampler), lodMinClamp, lodMaxClamp, index);
    }
}

void MTLComputeCommandEncoderSetThreadgroupMemoryLength(MTLComputeCommandEncoderRef encoder, uint64_t length, uint64_t index) {
    if (encoder) {
        static_cast<MTL::ComputeCommandEncoder*>(encoder)->setThreadgroupMemoryLength(length, index);
    }
}

void MTLComputeCommandEncoderDispatchThreadgroups(MTLComputeCommandEncoderRef encoder, MTLSize threadgroupsPerGrid, MTLSize threadsPerThreadgroup) {
    if (encoder) {
        static_cast<MTL::ComputeCommandEncoder*>(encoder)->dispatchThreadgroups(
            MTL::Size::Make(threadgroupsPerGrid.width, threadgroupsPerGrid.height, threadgroupsPerGrid.depth),
            MTL::Size::Make(threadsPerThreadgroup.width, threadsPerThreadgroup.height, threadsPerThreadgroup.depth)
        );
    }
}

void MTLComputeCommandEncoderDispatchThreads(MTLComputeCommandEncoderRef encoder, MTLSize threadsPerGrid, MTLSize threadsPerThreadgroup) {
    if (encoder) {
        static_cast<MTL::ComputeCommandEncoder*>(encoder)->dispatchThreads(
            MTL::Size::Make(threadsPerGrid.width, threadsPerGrid.height, threadsPerGrid.depth),
            MTL::Size::Make(threadsPerThreadgroup.width, threadsPerThreadgroup.height, threadsPerThreadgroup.depth)
        );
    }
}

void MTLComputeCommandEncoderDispatchThreadgroupsWithIndirectBuffer(MTLComputeCommandEncoderRef encoder, MTLBufferRef indirectBuffer, uint64_t offset, MTLSize threadsPerThreadgroup) {
    if (encoder && indirectBuffer) {
        static_cast<MTL::ComputeCommandEncoder*>(encoder)->dispatchThreadgroups(
            static_cast<MTL::Buffer*>(indirectBuffer),
            offset,
            MTL::Size::Make(threadsPerThreadgroup.width, threadsPerThreadgroup.height, threadsPerThreadgroup.depth)
        );
    }
}

void MTLComputeCommandEncoderUseResource(MTLComputeCommandEncoderRef encoder, void* resource, MTLResourceUsage usage) {
    if (encoder && resource) {
        static_cast<MTL::ComputeCommandEncoder*>(encoder)->useResource(static_cast<MTL::Resource*>(resource), static_cast<MTL::ResourceUsage>(usage));
    }
}

void MTLComputeCommandEncoderUseResources(MTLComputeCommandEncoderRef encoder, void** resources, uint64_t count, MTLResourceUsage usage) {
    if (encoder && resources) {
        static_cast<MTL::ComputeCommandEncoder*>(encoder)->useResources(reinterpret_cast<MTL::Resource**>(resources), count, static_cast<MTL::ResourceUsage>(usage));
    }
}

void MTLComputeCommandEncoderUseHeap(MTLComputeCommandEncoderRef encoder, MTLHeapRef heap) {
    if (encoder && heap) {
        static_cast<MTL::ComputeCommandEncoder*>(encoder)->useHeap(static_cast<MTL::Heap*>(heap));
    }
}

void MTLComputeCommandEncoderUseHeaps(MTLComputeCommandEncoderRef encoder, MTLHeapRef* heaps, uint64_t count) {
    if (encoder && heaps) {
        static_cast<MTL::ComputeCommandEncoder*>(encoder)->useHeaps(reinterpret_cast<MTL::Heap**>(heaps), count);
    }
}

void MTLComputeCommandEncoderMemoryBarrierWithScope(MTLComputeCommandEncoderRef encoder, MTLBarrierScope scope) {
    if (encoder) {
        static_cast<MTL::ComputeCommandEncoder*>(encoder)->memoryBarrier(static_cast<MTL::BarrierScope>(scope));
    }
}

void MTLComputeCommandEncoderMemoryBarrierWithResources(MTLComputeCommandEncoderRef encoder, void** resources, uint64_t count) {
    if (encoder && resources) {
        static_cast<MTL::ComputeCommandEncoder*>(encoder)->memoryBarrier(reinterpret_cast<MTL::Resource**>(resources), count);
    }
}

void MTLComputeCommandEncoderSetStageInRegion(MTLComputeCommandEncoderRef encoder, MTLRegion region) {
    if (encoder) {
        MTL::Region mtlRegion;
        mtlRegion.origin = MTL::Origin::Make(region.origin.x, region.origin.y, region.origin.z);
        mtlRegion.size = MTL::Size::Make(region.size.width, region.size.height, region.size.depth);
        static_cast<MTL::ComputeCommandEncoder*>(encoder)->setStageInRegion(mtlRegion);
    }
}

void MTLComputeCommandEncoderSetImageblockWidth(MTLComputeCommandEncoderRef encoder, uint64_t width, uint64_t height) {
    if (encoder) {
        static_cast<MTL::ComputeCommandEncoder*>(encoder)->setImageblockWidth(width, height);
    }
}

void MTLComputeCommandEncoderUpdateFence(MTLComputeCommandEncoderRef encoder, MTLFenceRef fence) {
    if (encoder && fence) {
        static_cast<MTL::ComputeCommandEncoder*>(encoder)->updateFence(static_cast<MTL::Fence*>(fence));
    }
}

void MTLComputeCommandEncoderWaitForFence(MTLComputeCommandEncoderRef encoder, MTLFenceRef fence) {
    if (encoder && fence) {
        static_cast<MTL::ComputeCommandEncoder*>(encoder)->waitForFence(static_cast<MTL::Fence*>(fence));
    }
}

void MTLComputeCommandEncoderEndEncoding(MTLComputeCommandEncoderRef encoder) {
    if (encoder) static_cast<MTL::ComputeCommandEncoder*>(encoder)->endEncoding();
}

void MTLComputeCommandEncoderInsertDebugSignpost(MTLComputeCommandEncoderRef encoder, const char* string) {
    if (encoder && string) {
        static_cast<MTL::ComputeCommandEncoder*>(encoder)->insertDebugSignpost(NS::String::string(string, NS::UTF8StringEncoding));
    }
}

void MTLComputeCommandEncoderPushDebugGroup(MTLComputeCommandEncoderRef encoder, const char* string) {
    if (encoder && string) {
        static_cast<MTL::ComputeCommandEncoder*>(encoder)->pushDebugGroup(NS::String::string(string, NS::UTF8StringEncoding));
    }
}

void MTLComputeCommandEncoderPopDebugGroup(MTLComputeCommandEncoderRef encoder) {
    if (encoder) static_cast<MTL::ComputeCommandEncoder*>(encoder)->popDebugGroup();
}

MTLDeviceRef MTLComputeCommandEncoderDevice(MTLComputeCommandEncoderRef encoder) {
    return encoder ? static_cast<MTL::ComputeCommandEncoder*>(encoder)->device() : nullptr;
}

const char* MTLComputeCommandEncoderLabel(MTLComputeCommandEncoderRef encoder) {
    if (!encoder) return nullptr;
    auto* label = static_cast<MTL::ComputeCommandEncoder*>(encoder)->label();
    return label ? label->utf8String() : nullptr;
}

void MTLComputeCommandEncoderSetLabel(MTLComputeCommandEncoderRef encoder, const char* label) {
    if (encoder && label) {
        static_cast<MTL::ComputeCommandEncoder*>(encoder)->setLabel(NS::String::string(label, NS::UTF8StringEncoding));
    }
}

// =============================================================================
// MTLBlitCommandEncoder
// =============================================================================

void MTLBlitCommandEncoderCopyFromBuffer(MTLBlitCommandEncoderRef encoder, MTLBufferRef srcBuffer, uint64_t srcOffset, MTLBufferRef dstBuffer, uint64_t dstOffset, uint64_t size) {
    if (encoder && srcBuffer && dstBuffer) {
        static_cast<MTL::BlitCommandEncoder*>(encoder)->copyFromBuffer(
            static_cast<MTL::Buffer*>(srcBuffer), srcOffset,
            static_cast<MTL::Buffer*>(dstBuffer), dstOffset, size
        );
    }
}

void MTLBlitCommandEncoderCopyFromTexture(MTLBlitCommandEncoderRef encoder, MTLTextureRef srcTexture, uint64_t srcSlice, uint64_t srcLevel, MTLOrigin srcOrigin, MTLSize srcSize, MTLTextureRef dstTexture, uint64_t dstSlice, uint64_t dstLevel, MTLOrigin dstOrigin) {
    if (encoder && srcTexture && dstTexture) {
        static_cast<MTL::BlitCommandEncoder*>(encoder)->copyFromTexture(
            static_cast<MTL::Texture*>(srcTexture), srcSlice, srcLevel,
            MTL::Origin::Make(srcOrigin.x, srcOrigin.y, srcOrigin.z),
            MTL::Size::Make(srcSize.width, srcSize.height, srcSize.depth),
            static_cast<MTL::Texture*>(dstTexture), dstSlice, dstLevel,
            MTL::Origin::Make(dstOrigin.x, dstOrigin.y, dstOrigin.z)
        );
    }
}

void MTLBlitCommandEncoderCopyFromBufferToTexture(MTLBlitCommandEncoderRef encoder, MTLBufferRef srcBuffer, uint64_t srcOffset, uint64_t srcBytesPerRow, uint64_t srcBytesPerImage, MTLSize srcSize, MTLTextureRef dstTexture, uint64_t dstSlice, uint64_t dstLevel, MTLOrigin dstOrigin) {
    if (encoder && srcBuffer && dstTexture) {
        static_cast<MTL::BlitCommandEncoder*>(encoder)->copyFromBuffer(
            static_cast<MTL::Buffer*>(srcBuffer), srcOffset, srcBytesPerRow, srcBytesPerImage,
            MTL::Size::Make(srcSize.width, srcSize.height, srcSize.depth),
            static_cast<MTL::Texture*>(dstTexture), dstSlice, dstLevel,
            MTL::Origin::Make(dstOrigin.x, dstOrigin.y, dstOrigin.z)
        );
    }
}

void MTLBlitCommandEncoderCopyFromTextureToBuffer(MTLBlitCommandEncoderRef encoder, MTLTextureRef srcTexture, uint64_t srcSlice, uint64_t srcLevel, MTLOrigin srcOrigin, MTLSize srcSize, MTLBufferRef dstBuffer, uint64_t dstOffset, uint64_t dstBytesPerRow, uint64_t dstBytesPerImage) {
    if (encoder && srcTexture && dstBuffer) {
        static_cast<MTL::BlitCommandEncoder*>(encoder)->copyFromTexture(
            static_cast<MTL::Texture*>(srcTexture), srcSlice, srcLevel,
            MTL::Origin::Make(srcOrigin.x, srcOrigin.y, srcOrigin.z),
            MTL::Size::Make(srcSize.width, srcSize.height, srcSize.depth),
            static_cast<MTL::Buffer*>(dstBuffer), dstOffset, dstBytesPerRow, dstBytesPerImage
        );
    }
}

void MTLBlitCommandEncoderFillBuffer(MTLBlitCommandEncoderRef encoder, MTLBufferRef buffer, uint64_t offset, uint64_t length, uint8_t value) {
    if (encoder && buffer) {
        static_cast<MTL::BlitCommandEncoder*>(encoder)->fillBuffer(static_cast<MTL::Buffer*>(buffer), NS::Range::Make(offset, length), value);
    }
}

void MTLBlitCommandEncoderGenerateMipmapsForTexture(MTLBlitCommandEncoderRef encoder, MTLTextureRef texture) {
    if (encoder && texture) {
        static_cast<MTL::BlitCommandEncoder*>(encoder)->generateMipmaps(static_cast<MTL::Texture*>(texture));
    }
}

void MTLBlitCommandEncoderSynchronizeResource(MTLBlitCommandEncoderRef encoder, void* resource) {
    if (encoder && resource) {
        static_cast<MTL::BlitCommandEncoder*>(encoder)->synchronizeResource(static_cast<MTL::Resource*>(resource));
    }
}

void MTLBlitCommandEncoderSynchronizeTexture(MTLBlitCommandEncoderRef encoder, MTLTextureRef texture, uint64_t slice, uint64_t level) {
    if (encoder && texture) {
        static_cast<MTL::BlitCommandEncoder*>(encoder)->synchronizeTexture(static_cast<MTL::Texture*>(texture), slice, level);
    }
}

void MTLBlitCommandEncoderOptimizeContentsForGPUAccess(MTLBlitCommandEncoderRef encoder, MTLTextureRef texture) {
    if (encoder && texture) {
        static_cast<MTL::BlitCommandEncoder*>(encoder)->optimizeContentsForGPUAccess(static_cast<MTL::Texture*>(texture));
    }
}

void MTLBlitCommandEncoderOptimizeContentsForGPUAccessWithSlice(MTLBlitCommandEncoderRef encoder, MTLTextureRef texture, uint64_t slice, uint64_t level) {
    if (encoder && texture) {
        static_cast<MTL::BlitCommandEncoder*>(encoder)->optimizeContentsForGPUAccess(static_cast<MTL::Texture*>(texture), slice, level);
    }
}

void MTLBlitCommandEncoderOptimizeContentsForCPUAccess(MTLBlitCommandEncoderRef encoder, MTLTextureRef texture) {
    if (encoder && texture) {
        static_cast<MTL::BlitCommandEncoder*>(encoder)->optimizeContentsForCPUAccess(static_cast<MTL::Texture*>(texture));
    }
}

void MTLBlitCommandEncoderOptimizeContentsForCPUAccessWithSlice(MTLBlitCommandEncoderRef encoder, MTLTextureRef texture, uint64_t slice, uint64_t level) {
    if (encoder && texture) {
        static_cast<MTL::BlitCommandEncoder*>(encoder)->optimizeContentsForCPUAccess(static_cast<MTL::Texture*>(texture), slice, level);
    }
}

void MTLBlitCommandEncoderUpdateFence(MTLBlitCommandEncoderRef encoder, MTLFenceRef fence) {
    if (encoder && fence) {
        static_cast<MTL::BlitCommandEncoder*>(encoder)->updateFence(static_cast<MTL::Fence*>(fence));
    }
}

void MTLBlitCommandEncoderWaitForFence(MTLBlitCommandEncoderRef encoder, MTLFenceRef fence) {
    if (encoder && fence) {
        static_cast<MTL::BlitCommandEncoder*>(encoder)->waitForFence(static_cast<MTL::Fence*>(fence));
    }
}

void MTLBlitCommandEncoderEndEncoding(MTLBlitCommandEncoderRef encoder) {
    if (encoder) static_cast<MTL::BlitCommandEncoder*>(encoder)->endEncoding();
}

void MTLBlitCommandEncoderInsertDebugSignpost(MTLBlitCommandEncoderRef encoder, const char* string) {
    if (encoder && string) {
        static_cast<MTL::BlitCommandEncoder*>(encoder)->insertDebugSignpost(NS::String::string(string, NS::UTF8StringEncoding));
    }
}

void MTLBlitCommandEncoderPushDebugGroup(MTLBlitCommandEncoderRef encoder, const char* string) {
    if (encoder && string) {
        static_cast<MTL::BlitCommandEncoder*>(encoder)->pushDebugGroup(NS::String::string(string, NS::UTF8StringEncoding));
    }
}

void MTLBlitCommandEncoderPopDebugGroup(MTLBlitCommandEncoderRef encoder) {
    if (encoder) static_cast<MTL::BlitCommandEncoder*>(encoder)->popDebugGroup();
}

MTLDeviceRef MTLBlitCommandEncoderDevice(MTLBlitCommandEncoderRef encoder) {
    return encoder ? static_cast<MTL::BlitCommandEncoder*>(encoder)->device() : nullptr;
}

const char* MTLBlitCommandEncoderLabel(MTLBlitCommandEncoderRef encoder) {
    if (!encoder) return nullptr;
    auto* label = static_cast<MTL::BlitCommandEncoder*>(encoder)->label();
    return label ? label->utf8String() : nullptr;
}

void MTLBlitCommandEncoderSetLabel(MTLBlitCommandEncoderRef encoder, const char* label) {
    if (encoder && label) {
        static_cast<MTL::BlitCommandEncoder*>(encoder)->setLabel(NS::String::string(label, NS::UTF8StringEncoding));
    }
}

// =============================================================================
// MTLTexture (partial - key methods)
// =============================================================================

uint64_t MTLTextureWidth(MTLTextureRef texture) {
    return texture ? static_cast<MTL::Texture*>(texture)->width() : 0;
}

uint64_t MTLTextureHeight(MTLTextureRef texture) {
    return texture ? static_cast<MTL::Texture*>(texture)->height() : 0;
}

uint64_t MTLTextureDepth(MTLTextureRef texture) {
    return texture ? static_cast<MTL::Texture*>(texture)->depth() : 0;
}

uint64_t MTLTextureMipmapLevelCount(MTLTextureRef texture) {
    return texture ? static_cast<MTL::Texture*>(texture)->mipmapLevelCount() : 0;
}

uint64_t MTLTextureArrayLength(MTLTextureRef texture) {
    return texture ? static_cast<MTL::Texture*>(texture)->arrayLength() : 0;
}

uint64_t MTLTextureSampleCount(MTLTextureRef texture) {
    return texture ? static_cast<MTL::Texture*>(texture)->sampleCount() : 0;
}

MTLTextureType MTLTextureTextureType(MTLTextureRef texture) {
    return texture ? static_cast<MTLTextureType>(static_cast<MTL::Texture*>(texture)->textureType()) : MTLTextureType2D;
}

MTLPixelFormat MTLTexturePixelFormat(MTLTextureRef texture) {
    return texture ? static_cast<MTLPixelFormat>(static_cast<MTL::Texture*>(texture)->pixelFormat()) : MTLPixelFormatInvalid;
}

MTLTextureUsage MTLTextureGetUsage(MTLTextureRef texture) {
    return texture ? static_cast<MTLTextureUsage>(static_cast<MTL::Texture*>(texture)->usage()) : MTLTextureUsageUnknown;
}

void MTLTextureReplaceRegion(MTLTextureRef texture, MTLRegion region, uint64_t level, uint64_t slice, const void* bytes, uint64_t bytesPerRow, uint64_t bytesPerImage) {
    if (texture && bytes) {
        MTL::Region mtlRegion;
        mtlRegion.origin = MTL::Origin::Make(region.origin.x, region.origin.y, region.origin.z);
        mtlRegion.size = MTL::Size::Make(region.size.width, region.size.height, region.size.depth);
        static_cast<MTL::Texture*>(texture)->replaceRegion(mtlRegion, level, slice, bytes, bytesPerRow, bytesPerImage);
    }
}

void MTLTextureGetBytes(MTLTextureRef texture, void* bytes, uint64_t bytesPerRow, uint64_t bytesPerImage, MTLRegion region, uint64_t level, uint64_t slice) {
    if (texture && bytes) {
        MTL::Region mtlRegion;
        mtlRegion.origin = MTL::Origin::Make(region.origin.x, region.origin.y, region.origin.z);
        mtlRegion.size = MTL::Size::Make(region.size.width, region.size.height, region.size.depth);
        static_cast<MTL::Texture*>(texture)->getBytes(bytes, bytesPerRow, bytesPerImage, mtlRegion, level, slice);
    }
}

MTLDeviceRef MTLTextureDevice(MTLTextureRef texture) {
    return texture ? static_cast<MTL::Texture*>(texture)->device() : nullptr;
}

const char* MTLTextureLabel(MTLTextureRef texture) {
    if (!texture) return nullptr;
    auto* label = static_cast<MTL::Texture*>(texture)->label();
    return label ? label->utf8String() : nullptr;
}

void MTLTextureSetLabel(MTLTextureRef texture, const char* label) {
    if (texture && label) {
        static_cast<MTL::Texture*>(texture)->setLabel(NS::String::string(label, NS::UTF8StringEncoding));
    }
}

// =============================================================================
// MTLHeap
// =============================================================================

uint64_t MTLHeapSize(MTLHeapRef heap) {
    return heap ? static_cast<MTL::Heap*>(heap)->size() : 0;
}

uint64_t MTLHeapUsedSize(MTLHeapRef heap) {
    return heap ? static_cast<MTL::Heap*>(heap)->usedSize() : 0;
}

uint64_t MTLHeapCurrentAllocatedSize(MTLHeapRef heap) {
    return heap ? static_cast<MTL::Heap*>(heap)->currentAllocatedSize() : 0;
}

uint64_t MTLHeapMaxAvailableSizeWithAlignment(MTLHeapRef heap, uint64_t alignment) {
    return heap ? static_cast<MTL::Heap*>(heap)->maxAvailableSize(alignment) : 0;
}

MTLBufferRef MTLHeapNewBufferWithLength(MTLHeapRef heap, uint64_t length, MTLResourceOptions options) {
    return heap ? static_cast<MTL::Heap*>(heap)->newBuffer(length, static_cast<MTL::ResourceOptions>(options)) : nullptr;
}

MTLTextureRef MTLHeapNewTextureWithDescriptor(MTLHeapRef heap, MTLTextureDescriptorRef descriptor) {
    return (heap && descriptor) ? static_cast<MTL::Heap*>(heap)->newTexture(static_cast<MTL::TextureDescriptor*>(descriptor)) : nullptr;
}

MTLDeviceRef MTLHeapDevice(MTLHeapRef heap) {
    return heap ? static_cast<MTL::Heap*>(heap)->device() : nullptr;
}

const char* MTLHeapLabel(MTLHeapRef heap) {
    if (!heap) return nullptr;
    auto* label = static_cast<MTL::Heap*>(heap)->label();
    return label ? label->utf8String() : nullptr;
}

void MTLHeapSetLabel(MTLHeapRef heap, const char* label) {
    if (heap && label) {
        static_cast<MTL::Heap*>(heap)->setLabel(NS::String::string(label, NS::UTF8StringEncoding));
    }
}

MTLHeapType MTLHeapGetType(MTLHeapRef heap) {
    return heap ? static_cast<MTLHeapType>(static_cast<MTL::Heap*>(heap)->type()) : MTLHeapTypeAutomatic;
}

// =============================================================================
// MTLEvent / MTLSharedEvent
// =============================================================================

MTLDeviceRef MTLEventDevice(MTLEventRef event) {
    return event ? static_cast<MTL::Event*>(event)->device() : nullptr;
}

const char* MTLEventLabel(MTLEventRef event) {
    if (!event) return nullptr;
    auto* label = static_cast<MTL::Event*>(event)->label();
    return label ? label->utf8String() : nullptr;
}

void MTLEventSetLabel(MTLEventRef event, const char* label) {
    if (event && label) {
        static_cast<MTL::Event*>(event)->setLabel(NS::String::string(label, NS::UTF8StringEncoding));
    }
}

uint64_t MTLSharedEventSignaledValue(MTLSharedEventRef event) {
    return event ? static_cast<MTL::SharedEvent*>(event)->signaledValue() : 0;
}

void MTLSharedEventSetSignaledValue(MTLSharedEventRef event, uint64_t value) {
    if (event) static_cast<MTL::SharedEvent*>(event)->setSignaledValue(value);
}

// =============================================================================
// MTLFence
// =============================================================================

MTLDeviceRef MTLFenceDevice(MTLFenceRef fence) {
    return fence ? static_cast<MTL::Fence*>(fence)->device() : nullptr;
}

const char* MTLFenceLabel(MTLFenceRef fence) {
    if (!fence) return nullptr;
    auto* label = static_cast<MTL::Fence*>(fence)->label();
    return label ? label->utf8String() : nullptr;
}

void MTLFenceSetLabel(MTLFenceRef fence, const char* label) {
    if (fence && label) {
        static_cast<MTL::Fence*>(fence)->setLabel(NS::String::string(label, NS::UTF8StringEncoding));
    }
}

// =============================================================================
// Descriptors - MTLTextureDescriptor
// =============================================================================

MTLTextureDescriptorRef MTLTextureDescriptorCreate(void) {
    return MTL::TextureDescriptor::alloc()->init();
}

void MTLTextureDescriptorSetTextureType(MTLTextureDescriptorRef desc, MTLTextureType type) {
    if (desc) static_cast<MTL::TextureDescriptor*>(desc)->setTextureType(static_cast<MTL::TextureType>(type));
}

void MTLTextureDescriptorSetPixelFormat(MTLTextureDescriptorRef desc, MTLPixelFormat format) {
    if (desc) static_cast<MTL::TextureDescriptor*>(desc)->setPixelFormat(static_cast<MTL::PixelFormat>(format));
}

void MTLTextureDescriptorSetWidth(MTLTextureDescriptorRef desc, uint64_t width) {
    if (desc) static_cast<MTL::TextureDescriptor*>(desc)->setWidth(width);
}

void MTLTextureDescriptorSetHeight(MTLTextureDescriptorRef desc, uint64_t height) {
    if (desc) static_cast<MTL::TextureDescriptor*>(desc)->setHeight(height);
}

void MTLTextureDescriptorSetDepth(MTLTextureDescriptorRef desc, uint64_t depth) {
    if (desc) static_cast<MTL::TextureDescriptor*>(desc)->setDepth(depth);
}

void MTLTextureDescriptorSetMipmapLevelCount(MTLTextureDescriptorRef desc, uint64_t count) {
    if (desc) static_cast<MTL::TextureDescriptor*>(desc)->setMipmapLevelCount(count);
}

void MTLTextureDescriptorSetArrayLength(MTLTextureDescriptorRef desc, uint64_t length) {
    if (desc) static_cast<MTL::TextureDescriptor*>(desc)->setArrayLength(length);
}

void MTLTextureDescriptorSetSampleCount(MTLTextureDescriptorRef desc, uint64_t count) {
    if (desc) static_cast<MTL::TextureDescriptor*>(desc)->setSampleCount(count);
}

void MTLTextureDescriptorSetStorageMode(MTLTextureDescriptorRef desc, MTLStorageMode mode) {
    if (desc) static_cast<MTL::TextureDescriptor*>(desc)->setStorageMode(static_cast<MTL::StorageMode>(mode));
}

void MTLTextureDescriptorSetUsage(MTLTextureDescriptorRef desc, MTLTextureUsage usage) {
    if (desc) static_cast<MTL::TextureDescriptor*>(desc)->setUsage(static_cast<MTL::TextureUsage>(usage));
}

MTLTextureDescriptorRef MTLTextureDescriptorTexture2DDescriptor(MTLPixelFormat format, uint64_t width, uint64_t height, bool mipmapped) {
    return MTL::TextureDescriptor::texture2DDescriptor(static_cast<MTL::PixelFormat>(format), width, height, mipmapped);
}

MTLTextureDescriptorRef MTLTextureDescriptorTextureCubeDescriptor(MTLPixelFormat format, uint64_t size, bool mipmapped) {
    return MTL::TextureDescriptor::textureCubeDescriptor(static_cast<MTL::PixelFormat>(format), size, mipmapped);
}

// =============================================================================
// Descriptors - MTLSamplerDescriptor
// =============================================================================

MTLSamplerDescriptorRef MTLSamplerDescriptorCreate(void) {
    return MTL::SamplerDescriptor::alloc()->init();
}

void MTLSamplerDescriptorSetMinFilter(MTLSamplerDescriptorRef desc, MTLSamplerMinMagFilter filter) {
    if (desc) static_cast<MTL::SamplerDescriptor*>(desc)->setMinFilter(static_cast<MTL::SamplerMinMagFilter>(filter));
}

void MTLSamplerDescriptorSetMagFilter(MTLSamplerDescriptorRef desc, MTLSamplerMinMagFilter filter) {
    if (desc) static_cast<MTL::SamplerDescriptor*>(desc)->setMagFilter(static_cast<MTL::SamplerMinMagFilter>(filter));
}

void MTLSamplerDescriptorSetMipFilter(MTLSamplerDescriptorRef desc, MTLSamplerMipFilter filter) {
    if (desc) static_cast<MTL::SamplerDescriptor*>(desc)->setMipFilter(static_cast<MTL::SamplerMipFilter>(filter));
}

void MTLSamplerDescriptorSetSAddressMode(MTLSamplerDescriptorRef desc, MTLSamplerAddressMode mode) {
    if (desc) static_cast<MTL::SamplerDescriptor*>(desc)->setSAddressMode(static_cast<MTL::SamplerAddressMode>(mode));
}

void MTLSamplerDescriptorSetTAddressMode(MTLSamplerDescriptorRef desc, MTLSamplerAddressMode mode) {
    if (desc) static_cast<MTL::SamplerDescriptor*>(desc)->setTAddressMode(static_cast<MTL::SamplerAddressMode>(mode));
}

void MTLSamplerDescriptorSetRAddressMode(MTLSamplerDescriptorRef desc, MTLSamplerAddressMode mode) {
    if (desc) static_cast<MTL::SamplerDescriptor*>(desc)->setRAddressMode(static_cast<MTL::SamplerAddressMode>(mode));
}

void MTLSamplerDescriptorSetMaxAnisotropy(MTLSamplerDescriptorRef desc, uint64_t value) {
    if (desc) static_cast<MTL::SamplerDescriptor*>(desc)->setMaxAnisotropy(value);
}

void MTLSamplerDescriptorSetCompareFunction(MTLSamplerDescriptorRef desc, MTLCompareFunction func) {
    if (desc) static_cast<MTL::SamplerDescriptor*>(desc)->setCompareFunction(static_cast<MTL::CompareFunction>(func));
}

void MTLSamplerDescriptorSetLodMinClamp(MTLSamplerDescriptorRef desc, float value) {
    if (desc) static_cast<MTL::SamplerDescriptor*>(desc)->setLodMinClamp(value);
}

void MTLSamplerDescriptorSetLodMaxClamp(MTLSamplerDescriptorRef desc, float value) {
    if (desc) static_cast<MTL::SamplerDescriptor*>(desc)->setLodMaxClamp(value);
}

void MTLSamplerDescriptorSetNormalizedCoordinates(MTLSamplerDescriptorRef desc, bool normalized) {
    if (desc) static_cast<MTL::SamplerDescriptor*>(desc)->setNormalizedCoordinates(normalized);
}

void MTLSamplerDescriptorSetLabel(MTLSamplerDescriptorRef desc, const char* label) {
    if (desc && label) {
        static_cast<MTL::SamplerDescriptor*>(desc)->setLabel(NS::String::string(label, NS::UTF8StringEncoding));
    }
}

// =============================================================================
// Descriptors - MTLDepthStencilDescriptor
// =============================================================================

MTLDepthStencilDescriptorRef MTLDepthStencilDescriptorCreate(void) {
    return MTL::DepthStencilDescriptor::alloc()->init();
}

void MTLDepthStencilDescriptorSetDepthCompareFunction(MTLDepthStencilDescriptorRef desc, MTLCompareFunction func) {
    if (desc) static_cast<MTL::DepthStencilDescriptor*>(desc)->setDepthCompareFunction(static_cast<MTL::CompareFunction>(func));
}

void MTLDepthStencilDescriptorSetDepthWriteEnabled(MTLDepthStencilDescriptorRef desc, bool enabled) {
    if (desc) static_cast<MTL::DepthStencilDescriptor*>(desc)->setDepthWriteEnabled(enabled);
}

void MTLDepthStencilDescriptorSetLabel(MTLDepthStencilDescriptorRef desc, const char* label) {
    if (desc && label) {
        static_cast<MTL::DepthStencilDescriptor*>(desc)->setLabel(NS::String::string(label, NS::UTF8StringEncoding));
    }
}

// =============================================================================
// Descriptors - MTLRenderPassDescriptor
// =============================================================================

MTLRenderPassDescriptorRef MTLRenderPassDescriptorCreate(void) {
    return MTL::RenderPassDescriptor::alloc()->init();
}

void MTLRenderPassDescriptorSetColorAttachmentTexture(MTLRenderPassDescriptorRef desc, uint64_t index, MTLTextureRef texture) {
    if (desc) {
        static_cast<MTL::RenderPassDescriptor*>(desc)->colorAttachments()->object(index)->setTexture(static_cast<MTL::Texture*>(texture));
    }
}

void MTLRenderPassDescriptorSetColorAttachmentLoadAction(MTLRenderPassDescriptorRef desc, uint64_t index, MTLLoadAction action) {
    if (desc) {
        static_cast<MTL::RenderPassDescriptor*>(desc)->colorAttachments()->object(index)->setLoadAction(static_cast<MTL::LoadAction>(action));
    }
}

void MTLRenderPassDescriptorSetColorAttachmentStoreAction(MTLRenderPassDescriptorRef desc, uint64_t index, MTLStoreAction action) {
    if (desc) {
        static_cast<MTL::RenderPassDescriptor*>(desc)->colorAttachments()->object(index)->setStoreAction(static_cast<MTL::StoreAction>(action));
    }
}

void MTLRenderPassDescriptorSetColorAttachmentClearColor(MTLRenderPassDescriptorRef desc, uint64_t index, MTLClearColor color) {
    if (desc) {
        static_cast<MTL::RenderPassDescriptor*>(desc)->colorAttachments()->object(index)->setClearColor(MTL::ClearColor::Make(color.red, color.green, color.blue, color.alpha));
    }
}

void MTLRenderPassDescriptorSetDepthAttachmentTexture(MTLRenderPassDescriptorRef desc, MTLTextureRef texture) {
    if (desc) {
        static_cast<MTL::RenderPassDescriptor*>(desc)->depthAttachment()->setTexture(static_cast<MTL::Texture*>(texture));
    }
}

void MTLRenderPassDescriptorSetDepthAttachmentLoadAction(MTLRenderPassDescriptorRef desc, MTLLoadAction action) {
    if (desc) {
        static_cast<MTL::RenderPassDescriptor*>(desc)->depthAttachment()->setLoadAction(static_cast<MTL::LoadAction>(action));
    }
}

void MTLRenderPassDescriptorSetDepthAttachmentStoreAction(MTLRenderPassDescriptorRef desc, MTLStoreAction action) {
    if (desc) {
        static_cast<MTL::RenderPassDescriptor*>(desc)->depthAttachment()->setStoreAction(static_cast<MTL::StoreAction>(action));
    }
}

void MTLRenderPassDescriptorSetDepthAttachmentClearDepth(MTLRenderPassDescriptorRef desc, double depth) {
    if (desc) {
        static_cast<MTL::RenderPassDescriptor*>(desc)->depthAttachment()->setClearDepth(depth);
    }
}

// =============================================================================
// Descriptors - MTLHeapDescriptor
// =============================================================================

MTLHeapDescriptorRef MTLHeapDescriptorCreate(void) {
    return MTL::HeapDescriptor::alloc()->init();
}

void MTLHeapDescriptorSetSize(MTLHeapDescriptorRef desc, uint64_t size) {
    if (desc) static_cast<MTL::HeapDescriptor*>(desc)->setSize(size);
}

void MTLHeapDescriptorSetStorageMode(MTLHeapDescriptorRef desc, MTLStorageMode mode) {
    if (desc) static_cast<MTL::HeapDescriptor*>(desc)->setStorageMode(static_cast<MTL::StorageMode>(mode));
}

void MTLHeapDescriptorSetCPUCacheMode(MTLHeapDescriptorRef desc, MTLCPUCacheMode mode) {
    if (desc) static_cast<MTL::HeapDescriptor*>(desc)->setCpuCacheMode(static_cast<MTL::CPUCacheMode>(mode));
}

void MTLHeapDescriptorSetType(MTLHeapDescriptorRef desc, MTLHeapType type) {
    if (desc) static_cast<MTL::HeapDescriptor*>(desc)->setType(static_cast<MTL::HeapType>(type));
}

// =============================================================================
// Descriptors - MTLRenderPipelineDescriptor
// =============================================================================

MTLRenderPipelineDescriptorRef MTLRenderPipelineDescriptorCreate(void) {
    return MTL::RenderPipelineDescriptor::alloc()->init();
}

void MTLRenderPipelineDescriptorSetVertexFunction(MTLRenderPipelineDescriptorRef desc, MTLFunctionRef function) {
    if (desc) static_cast<MTL::RenderPipelineDescriptor*>(desc)->setVertexFunction(static_cast<MTL::Function*>(function));
}

void MTLRenderPipelineDescriptorSetFragmentFunction(MTLRenderPipelineDescriptorRef desc, MTLFunctionRef function) {
    if (desc) static_cast<MTL::RenderPipelineDescriptor*>(desc)->setFragmentFunction(static_cast<MTL::Function*>(function));
}

void MTLRenderPipelineDescriptorSetColorAttachmentPixelFormat(MTLRenderPipelineDescriptorRef desc, uint64_t index, MTLPixelFormat format) {
    if (desc) {
        static_cast<MTL::RenderPipelineDescriptor*>(desc)->colorAttachments()->object(index)->setPixelFormat(static_cast<MTL::PixelFormat>(format));
    }
}

void MTLRenderPipelineDescriptorSetDepthAttachmentPixelFormat(MTLRenderPipelineDescriptorRef desc, MTLPixelFormat format) {
    if (desc) static_cast<MTL::RenderPipelineDescriptor*>(desc)->setDepthAttachmentPixelFormat(static_cast<MTL::PixelFormat>(format));
}

void MTLRenderPipelineDescriptorSetStencilAttachmentPixelFormat(MTLRenderPipelineDescriptorRef desc, MTLPixelFormat format) {
    if (desc) static_cast<MTL::RenderPipelineDescriptor*>(desc)->setStencilAttachmentPixelFormat(static_cast<MTL::PixelFormat>(format));
}

void MTLRenderPipelineDescriptorSetSampleCount(MTLRenderPipelineDescriptorRef desc, uint64_t count) {
    if (desc) static_cast<MTL::RenderPipelineDescriptor*>(desc)->setSampleCount(count);
}

void MTLRenderPipelineDescriptorSetLabel(MTLRenderPipelineDescriptorRef desc, const char* label) {
    if (desc && label) {
        static_cast<MTL::RenderPipelineDescriptor*>(desc)->setLabel(NS::String::string(label, NS::UTF8StringEncoding));
    }
}

// =============================================================================
// Descriptors - MTLComputePipelineDescriptor
// =============================================================================

MTLComputePipelineDescriptorRef MTLComputePipelineDescriptorCreate(void) {
    return MTL::ComputePipelineDescriptor::alloc()->init();
}

void MTLComputePipelineDescriptorSetComputeFunction(MTLComputePipelineDescriptorRef desc, MTLFunctionRef function) {
    if (desc) static_cast<MTL::ComputePipelineDescriptor*>(desc)->setComputeFunction(static_cast<MTL::Function*>(function));
}

void MTLComputePipelineDescriptorSetThreadGroupSizeIsMultipleOfThreadExecutionWidth(MTLComputePipelineDescriptorRef desc, bool value) {
    if (desc) static_cast<MTL::ComputePipelineDescriptor*>(desc)->setThreadGroupSizeIsMultipleOfThreadExecutionWidth(value);
}

void MTLComputePipelineDescriptorSetMaxTotalThreadsPerThreadgroup(MTLComputePipelineDescriptorRef desc, uint64_t count) {
    if (desc) static_cast<MTL::ComputePipelineDescriptor*>(desc)->setMaxTotalThreadsPerThreadgroup(count);
}

void MTLComputePipelineDescriptorSetLabel(MTLComputePipelineDescriptorRef desc, const char* label) {
    if (desc && label) {
        static_cast<MTL::ComputePipelineDescriptor*>(desc)->setLabel(NS::String::string(label, NS::UTF8StringEncoding));
    }
}

// =============================================================================
// Descriptors - MTLCompileOptions
// =============================================================================

MTLCompileOptionsRef MTLCompileOptionsCreate(void) {
    return MTL::CompileOptions::alloc()->init();
}

void MTLCompileOptionsSetFastMathEnabled(MTLCompileOptionsRef options, bool enabled) {
    if (options) static_cast<MTL::CompileOptions*>(options)->setFastMathEnabled(enabled);
}

void MTLCompileOptionsSetLanguageVersion(MTLCompileOptionsRef options, uint64_t version) {
    if (options) static_cast<MTL::CompileOptions*>(options)->setLanguageVersion(static_cast<MTL::LanguageVersion>(version));
}

void MTLCompileOptionsSetPreserveInvariance(MTLCompileOptionsRef options, bool preserve) {
    if (options) static_cast<MTL::CompileOptions*>(options)->setPreserveInvariance(preserve);
}

} // extern "C"
