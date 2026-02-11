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
- **`c2pa.cpp`** - **Auto-generated during unity build** - standalone file containing all implementation code inline

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
Automatically generates and compiles a single standalone `c2pa.cpp` file:

```bash
cmake -S . -B build -DC2PA_UNITY_BUILD=ON
cmake --build build
```

In unity build mode:
- CMake auto-generates `src/c2pa.cpp` from all split source files
- The generated file is compiled as a single compilation unit
- The file is created during the build and placed in `src/`
- Perfect for distributing to artifact repositories like Artifactory

## Development Workflow

### Making Changes
1. Edit the relevant `c2pa_*.cpp` files (never edit `c2pa.cpp` directly)
2. Test with split build: `make` or `cmake --build build`
3. Build with unity mode to generate `c2pa.cpp`: `cmake -DC2PA_UNITY_BUILD=ON -B build/unity && cmake --build build/unity`
4. The generated `src/c2pa.cpp` can be uploaded to Artifactory for users who need a single file

### Important Notes
- **`c2pa.cpp` is auto-generated during unity build** - do not edit it manually
- The file is listed in `.gitignore` and should not be checked into version control
- Unity build automatically regenerates `c2pa.cpp` from split files when any source changes
- No manual script execution needed - CMake handles everything

## API Compatibility

Both build modes produce identical symbols and maintain full API compatibility. The choice only affects compilation, not runtime behavior or the public API surface.

Users of the library only need to include `c2pa.hpp` and link against `libc2pa_cpp.a` - the internal organization is transparent to consumers.
