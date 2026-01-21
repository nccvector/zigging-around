#!/usr/bin/env python3
"""
Metal Shim Generator using Regex Parsing

A simpler, more reliable approach that parses Metal headers using regex patterns.
This works better than libclang for Apple's Objective-C headers which use
complex macros and attributes.

Usage:
    python generate_shim_regex.py --protocols MTLDevice MTLCommandQueue MTLBuffer
"""

import re
import subprocess
from pathlib import Path
from dataclasses import dataclass, field


ZIG_KEYWORDS = {"error", "type", "align", "test", "pub", "const", "var", "fn", "return", "if", "else", "while", "for", "switch", "break", "continue", "null", "undefined", "true", "false", "and", "or", "orelse", "catch", "unreachable", "noreturn", "comptime", "inline", "extern", "export", "linksection", "threadlocal", "defer", "errdefer", "async", "await", "suspend", "resume", "try", "enum", "struct", "union", "opaque", "packed", "anytype", "anyopaque", "usingnamespace"}


# ============================================================================
# Known Global Functions
# ============================================================================
# These are standalone C functions exported by Metal, not methods on protocols.

GLOBAL_FUNCTIONS = [
    {
        "name": "mtl_create_system_default_device",
        "objc_call": "MTLCreateSystemDefaultDevice()",
        "return_c": "void *",
        "return_zig": "?MTLDevice",
        "params_c": "void",
        "params_zig": "",
        "doc": "Returns the default Metal device (GPU) for the system.",
    },
    {
        "name": "mtl_copy_all_devices",
        "objc_call": "MTLCopyAllDevices()",
        "return_c": "void *",
        "return_zig": "?*anyopaque",  # NSArray<id<MTLDevice>>*
        "params_c": "void",
        "params_zig": "",
        "doc": "Returns an array of all Metal devices available on the system.",
    },
]


# ============================================================================
# Manual Methods (methods with struct parameters that can't be auto-generated)
# ============================================================================
# These are methods that use Metal structs like MTLSize which we flatten to individual components.

MANUAL_METHODS = [
    {
        "name": "mtl_computecommandencoder_dispatch_threadgroups",
        "doc": "Dispatch compute work with explicit threadgroup counts.",
        "return_c": "void",
        "return_zig": "void",
        "params_c": "id<MTLComputeCommandEncoder> self_, uint64_t gridX, uint64_t gridY, uint64_t gridZ, uint64_t threadgroupX, uint64_t threadgroupY, uint64_t threadgroupZ",
        "params_zig": "self_: MTLComputeCommandEncoder, grid_x: u64, grid_y: u64, grid_z: u64, threadgroup_x: u64, threadgroup_y: u64, threadgroup_z: u64",
        "objc_impl": """    MTLSize grid = MTLSizeMake(gridX, gridY, gridZ);
    MTLSize threadgroup = MTLSizeMake(threadgroupX, threadgroupY, threadgroupZ);
    [self_ dispatchThreadgroups:grid threadsPerThreadgroup:threadgroup];""",
    },
    {
        "name": "mtl_computecommandencoder_dispatch_threads",
        "doc": "Dispatch compute work with explicit thread counts (non-uniform threadgroup).",
        "return_c": "void",
        "return_zig": "void",
        "params_c": "id<MTLComputeCommandEncoder> self_, uint64_t threadsX, uint64_t threadsY, uint64_t threadsZ, uint64_t threadgroupX, uint64_t threadgroupY, uint64_t threadgroupZ",
        "params_zig": "self_: MTLComputeCommandEncoder, threads_x: u64, threads_y: u64, threads_z: u64, threadgroup_x: u64, threadgroup_y: u64, threadgroup_z: u64",
        "objc_impl": """    MTLSize threads = MTLSizeMake(threadsX, threadsY, threadsZ);
    MTLSize threadgroup = MTLSizeMake(threadgroupX, threadgroupY, threadgroupZ);
    [self_ dispatchThreads:threads threadsPerThreadgroup:threadgroup];""",
    },
    {
        "name": "mtl_computecommandencoder_end_encoding",
        "doc": "End encoding commands to the compute command encoder.",
        "return_c": "void",
        "return_zig": "void",
        "params_c": "id<MTLComputeCommandEncoder> self_",
        "params_zig": "self_: MTLComputeCommandEncoder",
        "objc_impl": "    [self_ endEncoding];",
    },
    {
        "name": "mtl_commandbuffer_compute_command_encoder",
        "doc": "Create a compute command encoder from a command buffer.",
        "return_c": "void *",
        "return_zig": "?MTLComputeCommandEncoder",
        "params_c": "id<MTLCommandBuffer> self_",
        "params_zig": "self_: MTLCommandBuffer",
        "objc_impl": "    return [self_ computeCommandEncoder];",
    },
    {
        "name": "mtl_commandbuffer_commit",
        "doc": "Commit the command buffer for execution.",
        "return_c": "void",
        "return_zig": "void",
        "params_c": "id<MTLCommandBuffer> self_",
        "params_zig": "self_: MTLCommandBuffer",
        "objc_impl": "    [self_ commit];",
    },
    {
        "name": "mtl_commandbuffer_wait_until_completed",
        "doc": "Block until the command buffer has completed execution.",
        "return_c": "void",
        "return_zig": "void",
        "params_c": "id<MTLCommandBuffer> self_",
        "params_zig": "self_: MTLCommandBuffer",
        "objc_impl": "    [self_ waitUntilCompleted];",
    },
]


def safe_param_name(name: str) -> str:
    """Ensure parameter name isn't a Zig keyword."""
    if name in ZIG_KEYWORDS:
        return f"{name}_"
    return name


@dataclass
class ObjCParam:
    label: str       # The selector part (e.g., "withLength")
    name: str        # The parameter name (e.g., "length")
    objc_type: str   # Original type
    c_type: str      # C equivalent
    zig_type: str    # Zig equivalent


@dataclass
class ObjCMethod:
    selector: str
    c_name: str
    return_type_objc: str
    return_type_c: str
    return_type_zig: str
    params: list[ObjCParam] = field(default_factory=list)
    is_property: bool = False


@dataclass
class ObjCProtocol:
    name: str
    methods: list[ObjCMethod] = field(default_factory=list)


# ============================================================================
# Type Mapping
# ============================================================================

TYPE_MAP = {
    # Primitives
    "void": ("void", "void"),
    "BOOL": ("bool", "bool"),
    "bool": ("bool", "bool"),
    "NSUInteger": ("uint64_t", "u64"),
    "NSInteger": ("int64_t", "i64"),
    "uint64_t": ("uint64_t", "u64"),
    "uint32_t": ("uint32_t", "u32"),
    "uint16_t": ("uint16_t", "u16"),
    "uint8_t": ("uint8_t", "u8"),
    "int64_t": ("int64_t", "i64"),
    "CFTimeInterval": ("double", "f64"),
    "int32_t": ("int32_t", "i32"),
    "size_t": ("size_t", "usize"),
    "float": ("float", "f32"),
    "double": ("double", "f64"),
    # Strings
    "NSString *": ("const char *", "[*:0]const u8"),
    "NSString*": ("const char *", "[*:0]const u8"),
}


def map_type(objc_type: str) -> tuple[str, str, bool]:
    """Map Objective-C type to (C type, Zig type, is_struct).

    Returns is_struct=True for types that are structs and can't be easily wrapped.
    """
    objc_type = objc_type.strip()

    # Remove nullable annotations
    objc_type = re.sub(r'\b(nullable|_Nullable|__nullable)\b', '', objc_type).strip()
    objc_type = re.sub(r'\b(nonnull|_Nonnull|__nonnull)\b', '', objc_type).strip()
    objc_type = re.sub(r'\b(__autoreleasing)\b', '', objc_type).strip()
    objc_type = re.sub(r'\s+', ' ', objc_type).strip()

    # Direct mapping
    if objc_type in TYPE_MAP:
        c, z = TYPE_MAP[objc_type]
        return (c, z, False)

    # id<Protocol> -> opaque pointer
    if objc_type.startswith("id<") or objc_type == "id":
        return ("void *", "?*anyopaque", False)

    # NSError ** -> needs special handling
    if "NSError" in objc_type and "**" in objc_type:
        return ("NSError **", "?*?*anyopaque", False)  # Keep as NSError** for ObjC

    # Other ** -> opaque pointer
    if "**" in objc_type:
        return ("void **", "?*?*anyopaque", False)

    # Any pointer type -> opaque pointer
    if "*" in objc_type:
        return ("void *", "?*anyopaque", False)

    # MTL structs like MTLSize, MTLOrigin, MTLRegion, MTLSizeAndAlign - skip these
    # Also skip NSRange, NSData, array params like MTLRegion[]
    struct_types = {"MTLSize", "MTLOrigin", "MTLRegion", "MTLSizeAndAlign",
                    "MTLAccelerationStructureSizes", "MTLResourceID", "MTLCoordinate2D",
                    "MTLSamplePosition", "MTLClearColor", "MTLPackedFloat3", "MTLPackedFloat4x3",
                    "NSRange", "NSData", "dispatch_data_t", "dispatch_queue_t"}
    if objc_type in struct_types or any(s in objc_type for s in struct_types):
        return ("void *", "?*anyopaque", True)  # Mark as struct

    # MTL enums
    if objc_type.startswith("MTL"):
        return ("uint64_t", "u64", False)

    # Default
    return ("void *", "?*anyopaque", False)


def selector_to_c_name(protocol: str, selector: str) -> str:
    """Convert ObjC selector to C function name."""
    # mtl_device_new_buffer_with_length_options
    prefix = protocol.lower()
    if prefix.startswith("mtl"):
        prefix = "mtl_" + prefix[3:]

    name = selector.replace(":", "_")
    if name.endswith("_"):
        name = name[:-1]

    # camelCase -> snake_case
    name = re.sub(r'([a-z])([A-Z])', r'\1_\2', name).lower()

    return f"{prefix}_{name}"


# ============================================================================
# Header Parsing
# ============================================================================

def get_sdk_path() -> str:
    """Get macOS SDK path."""
    try:
        return subprocess.check_output(["xcrun", "--show-sdk-path"]).decode().strip()
    except:
        return "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"


def read_protocol_header(protocol_name: str) -> str:
    """Read the header file for a protocol."""
    sdk = get_sdk_path()

    # Map protocol names to header files
    header_map = {
        "MTLDevice": "MTLDevice.h",
        "MTLCommandQueue": "MTLCommandQueue.h",
        "MTLCommandBuffer": "MTLCommandBuffer.h",
        "MTLBuffer": "MTLBuffer.h",
        "MTLTexture": "MTLTexture.h",
        "MTLLibrary": "MTLLibrary.h",
        "MTLFunction": "MTLFunction.h",
        "MTLComputePipelineState": "MTLComputePipeline.h",
        "MTLComputeCommandEncoder": "MTLComputeCommandEncoder.h",
        "MTLBlitCommandEncoder": "MTLBlitCommandEncoder.h",
        "MTLRenderCommandEncoder": "MTLRenderCommandEncoder.h",
    }

    header_file = header_map.get(protocol_name, f"{protocol_name}.h")
    header_path = Path(sdk) / "System/Library/Frameworks/Metal.framework/Headers" / header_file

    if header_path.exists():
        return header_path.read_text()
    return ""


def strip_attributes(text: str) -> str:
    """Strip Apple attribute macros from text."""
    # Remove API_AVAILABLE(...), API_DEPRECATED(...) - handle nested parens (multiple times)
    for _ in range(3):  # Multiple passes to handle deeply nested
        text = re.sub(r'\bAPI_AVAILABLE\s*\([^()]*(?:\([^()]*\)[^()]*)*\)', '', text)
        text = re.sub(r'\bAPI_DEPRECATED\s*\([^()]*(?:\([^()]*\)[^()]*)*\)', '', text)
        text = re.sub(r'\bAPI_DEPRECATED_WITH_REPLACEMENT\s*\([^()]*(?:\([^()]*\)[^()]*)*\)', '', text)
    text = re.sub(r'\bAPI_UNAVAILABLE\s*\([^)]*\)', '', text)
    # NS_* macros
    text = re.sub(r'\bNS_AVAILABLE\s*\([^)]*\)', '', text)
    text = re.sub(r'\bNS_DEPRECATED\s*\([^)]*\)', '', text)
    text = re.sub(r'\bNS_RETURNS_INNER_POINTER\b', '', text)
    text = re.sub(r'\bNS_RETURNS_RETAINED\b', '', text)
    text = re.sub(r'\bNS_RETURNS_NOT_RETAINED\b', '', text)
    text = re.sub(r'\bNS_SWIFT_NAME\s*\([^)]*\)', '', text)
    text = re.sub(r'\bNS_REFINED_FOR_SWIFT\b', '', text)
    text = re.sub(r'\bNS_SWIFT_UNAVAILABLE\s*\([^)]*\)', '', text)
    # NS_SWIFT_UNAVAILABLE_FROM_ASYNC - contains quoted strings like ("Use 'await scheduled()' instead.")
    # The string contains parentheses inside quotes, so we need to match the whole thing including the quoted part
    text = re.sub(r'\bNS_SWIFT_UNAVAILABLE_FROM_ASYNC\s*\("[^"]*"\s*\)', '', text)
    text = re.sub(r'\bns_swift_unavailable_from_async\s*\("[^"]*"\s*\)', '', text)
    # Catch any remaining ", ios(...)" or ", macos(...)" fragments
    text = re.sub(r',\s*(ios|macos|tvos|watchos)\s*\([^)]*\)', '', text)
    # Clean up whitespace
    text = re.sub(r'\s+', ' ', text).strip()
    return text


def parse_protocol(header_content: str, protocol_name: str) -> ObjCProtocol:
    """Parse an Objective-C protocol definition."""
    protocol = ObjCProtocol(name=protocol_name)

    # Strip attributes from header first
    header_content = strip_attributes(header_content)

    # Find the protocol block
    # @protocol MTLDevice <...>
    # ... methods ...
    # @end
    pattern = rf'@protocol\s+{protocol_name}\s*<[^>]*>\s*(.*?)@end'
    match = re.search(pattern, header_content, re.DOTALL)

    if not match:
        print(f"  Warning: Could not find @protocol {protocol_name}")
        return protocol

    protocol_body = match.group(1)

    # Parse @property declarations
    # @property (readonly) NSString *name;
    # @property (readonly, getter=isLowPower) BOOL lowPower;
    prop_pattern = r'@property\s*\(([^)]*)\)\s*([^;]+)\s+(\w+)\s*;'
    for prop_match in re.finditer(prop_pattern, protocol_body):
        prop_attrs = prop_match.group(1)
        prop_type = prop_match.group(2).strip()
        prop_name = prop_match.group(3).strip()

        # Skip block types
        if "^" in prop_type or "Block" in prop_type:
            continue

        c_type, zig_type, is_struct = map_type(prop_type)

        # Skip struct-returning properties
        if is_struct:
            continue

        # Check for custom getter name
        getter_match = re.search(r'getter\s*=\s*(\w+)', prop_attrs)
        selector_name = getter_match.group(1) if getter_match else prop_name

        method = ObjCMethod(
            selector=selector_name,
            c_name=selector_to_c_name(protocol_name, prop_name),  # Use prop_name for C name
            return_type_objc=prop_type,
            return_type_c=c_type,
            return_type_zig=zig_type,
            is_property=True,
        )
        protocol.methods.append(method)

    # Parse method declarations
    # - (id<MTLCommandQueue>)newCommandQueue;
    # - (id<MTLBuffer>)newBufferWithLength:(NSUInteger)length options:(MTLResourceOptions)options;
    method_pattern = r'-\s*\(([^)]+)\)\s*([^;]+);'

    for method_match in re.finditer(method_pattern, protocol_body):
        return_type = method_match.group(1).strip()
        method_sig = method_match.group(2).strip()

        # Skip block return types
        if "^" in return_type or "Block" in return_type:
            continue

        # Skip methods with block parameters
        if "^" in method_sig or "Block" in method_sig:
            continue

        # Skip methods with handler/completion parameters (usually blocks)
        if "handler:" in method_sig.lower() or "completion:" in method_sig.lower():
            continue

        c_return, zig_return, is_struct = map_type(return_type)

        # Skip struct-returning methods
        if is_struct:
            continue

        # Parse method signature
        # Simple: newCommandQueue
        # With params: newBufferWithLength:(NSUInteger)length options:(MTLResourceOptions)options

        params = []
        selector_parts = []

        # Check if method has parameters (contains :)
        if ":" in method_sig:
            # Split by parameter pattern: label:(Type)name
            param_pattern = r'(\w+):\s*\(([^)]+)\)\s*(\w+)'
            for param_match in re.finditer(param_pattern, method_sig):
                label = param_match.group(1)
                param_type = param_match.group(2).strip()
                param_name = param_match.group(3)

                # Skip block params
                if "^" in param_type:
                    params = []  # Skip entire method
                    break

                c_type, zig_type, is_struct = map_type(param_type)

                # Skip methods with struct parameters
                if is_struct:
                    params = []  # Skip entire method
                    break

                params.append(ObjCParam(
                    label=label,
                    name=safe_param_name(param_name),
                    objc_type=param_type,
                    c_type=c_type,
                    zig_type=zig_type,
                ))
                selector_parts.append(f"{label}:")

            if not params:  # Had a block param
                continue

            selector = "".join(selector_parts)
        else:
            # No parameters
            selector = method_sig.strip()

        method = ObjCMethod(
            selector=selector,
            c_name=selector_to_c_name(protocol_name, selector),
            return_type_objc=return_type,
            return_type_c=c_return,
            return_type_zig=zig_return,
            params=params,
        )
        protocol.methods.append(method)

    return protocol


# ============================================================================
# Code Generation
# ============================================================================

def generate_objc_shim(protocols: list[ObjCProtocol]) -> str:
    """Generate Objective-C shim file."""
    lines = [
        "// Auto-generated Metal shim - DO NOT EDIT",
        "// Generated by generate_shim_regex.py",
        "",
        "#import <Metal/Metal.h>",
        "#import <Foundation/Foundation.h>",
        "",
        "// ============================================================================",
        "// Global Functions",
        "// ============================================================================",
        "",
    ]

    # Generate global functions from GLOBAL_FUNCTIONS
    for func in GLOBAL_FUNCTIONS:
        lines.append(f"// {func['doc']}")
        lines.append(f"{func['return_c']} {func['name']}({func['params_c']}) {{")
        lines.append(f"    return {func['objc_call']};")
        lines.append("}")
        lines.append("")

    # Generate manual methods
    lines.append("// ============================================================================")
    lines.append("// Manual Methods (struct parameters flattened)")
    lines.append("// ============================================================================")
    lines.append("")

    for method in MANUAL_METHODS:
        lines.append(f"// {method['doc']}")
        lines.append(f"{method['return_c']} {method['name']}({method['params_c']}) {{")
        lines.append(method['objc_impl'])
        lines.append("}")
        lines.append("")

    # Track used C names globally to avoid duplicates
    # Pre-populate with manual method names to avoid re-generating them
    used_c_names: set[str] = {m['name'] for m in MANUAL_METHODS}

    for protocol in protocols:
        lines.append(f"// ============================================================================")
        lines.append(f"// {protocol.name}")
        lines.append(f"// ============================================================================")
        lines.append("")

        for method in protocol.methods:
            # Handle duplicate C names by adding suffix
            base_c_name = method.c_name
            c_name = base_c_name
            suffix = 2
            while c_name in used_c_names:
                c_name = f"{base_c_name}_{suffix}"
                suffix += 1
            used_c_names.add(c_name)
            method.c_name = c_name  # Update for Zig bindings to match

            # Build parameter list
            params = [f"id<{protocol.name}> self_"]
            for p in method.params:
                params.append(f"{p.c_type} {p.name}")

            params_str = ", ".join(params) if params else "void"

            # Function signature
            lines.append(f"{method.return_type_c} {method.c_name}({params_str}) {{")

            # Build method call
            if method.params:
                call_parts = []
                for p in method.params:
                    # Cast NSError** properly
                    if p.c_type == "NSError **":
                        call_parts.append(f"{p.label}:(NSError **){p.name}")
                    # Convert const char* to NSString for NSString params
                    elif "NSString" in p.objc_type:
                        call_parts.append(f"{p.label}:[NSString stringWithUTF8String:{p.name}]")
                    # NSURL from const char*
                    elif "NSURL" in p.objc_type:
                        call_parts.append(f"{p.label}:[NSURL URLWithString:[NSString stringWithUTF8String:{p.name}]]")
                    else:
                        call_parts.append(f"{p.label}:{p.name}")
                call = " ".join(call_parts)
            else:
                call = method.selector

            # Handle return
            if "NSString" in method.return_type_objc:
                lines.append(f"    NSString *result = [self_ {call}];")
                lines.append(f"    return result ? [result UTF8String] : NULL;")
            elif method.return_type_c == "void":
                lines.append(f"    [self_ {call}];")
            else:
                lines.append(f"    return [self_ {call}];")

            lines.append("}")
            lines.append("")

    return "\n".join(lines)


def generate_zig_bindings(protocols: list[ObjCProtocol]) -> str:
    """Generate Zig bindings file."""
    lines = [
        "// Auto-generated Metal bindings for Zig - DO NOT EDIT",
        "// Generated by generate_shim_regex.py",
        "",
        "const std = @import(\"std\");",
        "",
        "// ============================================================================",
        "// Opaque Handle Types",
        "// ============================================================================",
        "",
    ]

    for protocol in protocols:
        lines.append(f"pub const {protocol.name} = *anyopaque;")

    lines.append("")
    lines.append("// ============================================================================")
    lines.append("// Global Functions")
    lines.append("// ============================================================================")
    lines.append("")

    # Generate global functions from GLOBAL_FUNCTIONS
    for func in GLOBAL_FUNCTIONS:
        lines.append(f"/// {func['doc']}")
        params_zig = func['params_zig'] if func['params_zig'] else ""
        lines.append(f'pub extern "c" fn {func["name"]}({params_zig}) {func["return_zig"]};')

    lines.append("")
    lines.append("// ============================================================================")
    lines.append("// Manual Methods (struct parameters flattened)")
    lines.append("// ============================================================================")
    lines.append("")

    # Generate manual methods
    for method in MANUAL_METHODS:
        lines.append(f"/// {method['doc']}")
        lines.append(f'pub extern "c" fn {method["name"]}({method["params_zig"]}) {method["return_zig"]};')

    lines.append("")
    lines.append("// ============================================================================")
    lines.append("// External C Functions")
    lines.append("// ============================================================================")
    lines.append("")

    # Track used names to avoid duplicates with manual methods
    used_zig_names: set[str] = {m['name'] for m in MANUAL_METHODS}

    for protocol in protocols:
        lines.append(f"// {protocol.name}")

        for method in protocol.methods:
            # Skip if already defined in manual methods
            if method.c_name in used_zig_names:
                continue
            used_zig_names.add(method.c_name)

            params = [f"self_: {protocol.name}"]
            for p in method.params:
                params.append(f"{p.name}: {p.zig_type}")

            params_str = ", ".join(params)
            lines.append(f'pub extern "c" fn {method.c_name}({params_str}) {method.return_type_zig};')

        lines.append("")

    lines.append("// ============================================================================")
    lines.append("// Zig Wrapper Structs")
    lines.append("// ============================================================================")
    lines.append("")

    for protocol in protocols:
        struct_name = protocol.name.replace("MTL", "")
        lines.append(f"pub const {struct_name} = struct {{")
        lines.append(f"    handle: {protocol.name},")
        lines.append("")

        # Track method names to avoid duplicates (Zig doesn't support overloading)
        seen_names: set[str] = set()

        for method in protocol.methods:
            # Skip methods already defined in manual methods
            if method.c_name in {m['name'] for m in MANUAL_METHODS}:
                continue

            # Method name: snake_case
            base_name = method.selector.split(":")[0]
            base_name = re.sub(r'([a-z])([A-Z])', r'\1_\2', base_name).lower()

            # Handle duplicate names by appending incrementing suffix
            method_name = base_name
            suffix = 2
            while method_name in seen_names:
                method_name = f"{base_name}_{suffix}"
                suffix += 1
            seen_names.add(method_name)

            # Escape method names that are Zig keywords/primitives
            if method_name in ZIG_KEYWORDS:
                method_name = f'@"{method_name}"'

            # Parameters
            params = ["self: @This()"]
            call_args = ["self.handle"]
            for p in method.params:
                params.append(f"{p.name}: {p.zig_type}")
                call_args.append(p.name)

            params_str = ", ".join(params)
            call_args_str = ", ".join(call_args)

            lines.append(f"    pub inline fn {method_name}({params_str}) {method.return_type_zig} {{")
            lines.append(f"        return {method.c_name}({call_args_str});")
            lines.append("    }")
            lines.append("")

        lines.append("};")
        lines.append("")

    return "\n".join(lines)


# ============================================================================
# Main
# ============================================================================

def main():
    import argparse

    parser = argparse.ArgumentParser(description="Generate Metal shims using regex parsing")
    parser.add_argument(
        "--protocols",
        nargs="+",
        default=["MTLDevice", "MTLCommandQueue", "MTLCommandBuffer", "MTLBuffer", "MTLLibrary", "MTLFunction", "MTLComputePipelineState", "MTLComputeCommandEncoder"],
        help="Protocols to generate shims for",
    )
    parser.add_argument(
        "--output-dir",
        default="./generated",
        help="Output directory",
    )
    args = parser.parse_args()

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    protocols = []

    print("Parsing Metal headers...")
    for protocol_name in args.protocols:
        print(f"  {protocol_name}...", end=" ")
        header = read_protocol_header(protocol_name)
        if header:
            protocol = parse_protocol(header, protocol_name)
            protocols.append(protocol)
            print(f"found {len(protocol.methods)} methods")
        else:
            print("header not found")

    print(f"\nGenerating shims for {sum(len(p.methods) for p in protocols)} total methods...")

    objc_code = generate_objc_shim(protocols)
    zig_code = generate_zig_bindings(protocols)

    objc_path = output_dir / "metal_shim.m"
    zig_path = output_dir / "metal.zig"

    objc_path.write_text(objc_code)
    zig_path.write_text(zig_code)

    print(f"\nGenerated:")
    print(f"  {objc_path}")
    print(f"  {zig_path}")

    # Print summary
    print(f"\nProtocol summary:")
    for p in protocols:
        print(f"  {p.name}: {len(p.methods)} methods")
        for m in p.methods[:3]:
            print(f"    - {m.selector}")
        if len(p.methods) > 3:
            print(f"    ... and {len(p.methods) - 3} more")


if __name__ == "__main__":
    main()
