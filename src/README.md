# C2PA C++ Source Organization

The C2PA C++ implementation is organized into multiple source files for better maintainability.

## File Structure

### Public API
- **`../include/c2pa.hpp`** - Public header file (unchanged)

### Internal Implementation

#### Shared Utilities
- **`c2pa_internal.hpp`** - Private header with shared implementation details (not installed)

#### Implementation Files (for development)
- **`c2pa_core.cpp`** - Exception class and free functions (`version()`, deprecated APIs)
- **`c2pa_settings.cpp`** - Settings class implementation
- **`c2pa_context.cpp`** - Context and ContextBuilder classes
- **`c2pa_streams.cpp`** - Stream wrappers (CppIStream, CppOStream, CppIOStream)
- **`c2pa_reader.cpp`** - Reader class implementation
- **`c2pa_signer.cpp`** - Signer class implementation
- **`c2pa_builder.cpp`** - Builder class implementation

#### Generated Standalone File (for distribution)
- **`c2pa.cpp`** - **Auto-generated** standalone file containing all implementation code inline

## Build Options

### Default: Split Build (Recommended for Development)
By default, the library is built from individual source files for better:
- Incremental compilation (faster rebuilds when changing a single file)
- Parallel compilation across multiple cores
- Code organization and maintainability

```bash
cmake -S . -B build
cmake --build build
```

### Unity Build (For Distribution)
For users who only have `c2pa.cpp` (e.g., from Artifactory):

```bash
cmake -S . -B build -DC2PA_UNITY_BUILD=ON
cmake --build build
```

In unity build mode, all implementation is compiled through a single standalone `c2pa.cpp` file.

## Development Workflow

### Making Changes
1. Edit the relevant `c2pa_*.cpp` files (never edit `c2pa.cpp` directly)
2. Test with split build: `make` or `cmake --build build`
3. Generate standalone `c2pa.cpp` for distribution: `./scripts/generate_c2pa_cpp.sh`
4. Test unity build: `cmake -DC2PA_UNITY_BUILD=ON ...`
5. Upload standalone `c2pa.cpp` to Artifactory

### Important Notes
- **`c2pa.cpp` is auto-generated** - do not edit it manually
- Always regenerate `c2pa.cpp` after making changes to split files
- The generation script concatenates all split files into a single standalone file

## Advantages of Each Approach

**Split Build (Development):**
- ✅ Faster incremental builds
- ✅ Better parallel compilation
- ✅ Easier to navigate and maintain
- ✅ One class per file
- ✅ Recommended for active development

**Unity Build (Distribution):**
- ✅ Single standalone file - no dependencies on split files
- ✅ Works with existing artifact repositories (Artifactory)
- ✅ Simpler for users who just want to compile
- ✅ May enable more compiler optimizations

## API Compatibility

Both build modes produce identical symbols and maintain full API compatibility. The choice only affects compilation, not runtime behavior or the public API surface.

Users of the library only need to include `c2pa.hpp` and link against `libc2pa_cpp.a` - the internal organization is transparent to consumers.
