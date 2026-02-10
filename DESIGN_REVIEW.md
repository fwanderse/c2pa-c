# C2PA-C Design Review & Refactoring Opportunities

## Context

This is a design review of the `c2pa-c` C++ wrapper library around the C2PA Rust FFI. The library provides APIs for reading/validating C2PA manifests and creating/signing manifests on media files. The review covers internal design quality, non-breaking refactoring opportunities, and recommendations for third-party extensibility.

---

## Part 1: Design Critique

### What Works Well

1. **Clean layered architecture**: `detail` namespace for internals, `c2pa` namespace for public API, clear FFI boundary
2. **RAII throughout**: Smart pointers, proper destructor ordering (e.g., `cpp_stream` before `owned_stream` in Reader)
3. **Consuming builder pattern**: `ContextBuilder` invalidates itself after `create_context()`, preventing misuse
4. **`IContextProvider` interface**: Enables dependency injection and third-party context implementations
5. **Stream abstraction via templates**: `StreamSeekTraits<T>` eliminates duplication across stream types
6. **`[[nodiscard]]` usage**: Prevents accidentally ignoring return values
7. **Factory methods on Context**: Private constructor forces use of `Context::create()` / `from_json()` / `from_toml()`

### Design Issues

#### 1. CppIStream delegates writer/flusher to `std::iostream` instead of `std::istream`

**Files**: `src/c2pa.cpp:573-581`

`CppIStream::writer()` and `CppIStream::flusher()` dispatch to `detail::stream_writer<std::iostream>` and `detail::stream_flusher<std::iostream>`. An input-only stream should not delegate write operations to an `iostream` cast -- if the C layer calls these, it would `reinterpret_cast` an `istream*` as an `iostream*`, which is undefined behavior. These should either return an error (like `CppOStream::reader()` does) or use `std::istream`.

#### 2. Signer callback silently swallows exceptions

**File**: `src/c2pa.cpp:70-81`

```cpp
catch (std::exception const &e) {
    (void)e;  // Exception silently discarded!
    return -1;
}
```

The `signer_passthrough` function catches exceptions and returns -1 with no error context. The TODO on line 72 acknowledges this. There's no mechanism to propagate error information back through the FFI boundary. At minimum, the error message should be stored in thread-local storage so `C2paException()` can pick it up later, or logged via a configurable callback.

#### 3. C-style cast in signer passthrough

**File**: `src/c2pa.cpp:60`

```cpp
c2pa::SignerFunc *callback = (c2pa::SignerFunc *)context;
```

This is a C-style cast of `const void*` to a function pointer type. Should be `reinterpret_cast` for explicitness and grep-ability. Also casts away `const`, which should be `const_cast` + `reinterpret_cast` if intentional.

#### 4. Inconsistent error types thrown across the API

The API throws a mix of:
- `C2paException()` (fetches error from C API)
- `C2paException("message")` (custom message)
- `std::system_error` (file not found, `src/c2pa.cpp:682`)
- `std::runtime_error` (destination file, `src/c2pa.cpp:1041`)

For a user catching errors, this is unpredictable. `Reader(path)` throws `std::system_error` for missing files, but `Builder::sign(path, path, signer)` throws `std::runtime_error` for the same situation. These should be unified -- either always `C2paException` wrapping the underlying error, or documented clearly which methods throw which types.

#### 5. `with_definition()` doesn't null the old pointer before checking the result

**File**: `src/c2pa.cpp:903-910`

```cpp
C2paBuilder* updated = c2pa_builder_with_definition(builder, manifest_json.c_str());
if (updated == nullptr) {
    throw C2paException("Failed to set builder definition");
}
builder = updated;  // Old builder leaked if c2pa_builder_with_definition consumed it
```

The comment pattern elsewhere (e.g., `src/c2pa.cpp:847-852`) correctly sets `builder = nullptr` before checking, acknowledging that the C API consumes the pointer. `with_definition()` doesn't do this -- if the C API consumed the old pointer and returned null, the destructor will double-free.

#### 6. `errno`-based error propagation is thread-unsafe

**File**: `include/c2pa.hpp:17`, `include/c2pa.hpp:71-74`

`stream_error_return()` sets `errno`, which is technically thread-local on most modern platforms, but the header comment says "Thread safety is not guaranteed due to the use of errno and etc." The "and etc." is vague. The real thread-safety concern is `c2pa_error()` in `C2paException::C2paException()` -- if two threads hit C API errors simultaneously, they may read each other's error strings.

#### 7. Deprecated API surface is large relative to the total API

4 deprecated free functions + 4 deprecated class constructors = 8 deprecated entry points out of ~30 total public API functions. This is ~27% of the API. The deprecated code paths also duplicate logic (e.g., Reader has two nearly-identical constructors for with/without context).

#### 8. `c_stream` is a public member on all stream wrappers

**File**: `include/c2pa.hpp:372`, `include/c2pa.hpp:405`, `include/c2pa.hpp:435`

`CppIStream::c_stream`, `CppOStream::c_stream`, `CppIOStream::c_stream` are all public. These are raw C pointers to FFI resources. Exposing them publicly breaks encapsulation and invites misuse (e.g., someone calling `c2pa_release_stream()` on them, causing double-free). They should be private with accessor methods.

#### 9. No way to inspect Builder state

Builder has no `json()` or similar method to inspect the current manifest definition. Users who call `with_definition()`, `add_action()`, etc. have no way to verify the accumulated state before signing. This makes debugging difficult.

#### 10. `Builder::sign` with `std::ostream` is deprecated but not marked as such

**File**: `include/c2pa.hpp:776`

The `sign(format, istream&, ostream&, signer)` overload has a comment saying it's deprecated in favor of the `iostream` version, but the `[[deprecated]]` attribute is only in the docstring comment, not applied to the declaration. The compiler won't warn users.

#### 11. Header includes `<iostream>` unnecessarily

**File**: `include/c2pa.hpp:37`

`<iostream>` pulls in `std::cin`, `std::cout`, `std::cerr` and their global constructors. The header only needs `<istream>`, `<ostream>`, and the individual stream types. In a library header, this adds unnecessary compile-time cost and binary bloat for every translation unit that includes `c2pa.hpp`.

---

## Part 2: Non-Breaking Refactoring Opportunities

### R1. Fix the `CppIStream` writer/flusher bug

Change `CppIStream::writer` and `CppIStream::flusher` to return an error (matching how `CppOStream::reader` already works), rather than delegating to `iostream`:

```cpp
intptr_t CppIStream::writer(StreamContext *context, const uint8_t *buffer, intptr_t size) {
    (void)context; (void)buffer; (void)size;
    return stream_error_return(StreamError::InvalidArgument);
}
intptr_t CppIStream::flusher(StreamContext *context) {
    (void)context;
    return stream_error_return(StreamError::InvalidArgument);
}
```

**Files**: `src/c2pa.cpp:573-581`

### R2. Fix the `with_definition()` pointer consumption bug

Null the builder pointer before checking the result, matching the pattern used in the constructor:

```cpp
Builder& Builder::with_definition(const std::string &manifest_json) {
    C2paBuilder* updated = c2pa_builder_with_definition(builder, manifest_json.c_str());
    builder = nullptr;  // C API consumed the old pointer
    if (updated == nullptr) {
        throw C2paException("Failed to set builder definition");
    }
    builder = updated;
    return *this;
}
```

**File**: `src/c2pa.cpp:903-910`

### R3. Make `c_stream` private on stream wrappers

Move `c_stream` to private and add a `c_stream()` accessor (or use existing `friend` declarations). This is non-breaking for library consumers since `c_stream` is an internal detail -- but if any third-party code reaches into `c_stream` directly, this could break them. Evaluate with care.

**Files**: `include/c2pa.hpp:372`, `include/c2pa.hpp:405`, `include/c2pa.hpp:435`

### R4. Replace C-style cast with `reinterpret_cast`

**File**: `src/c2pa.cpp:60`

```cpp
auto* callback = reinterpret_cast<c2pa::SignerFunc*>(const_cast<void*>(context));
```

### R5. Unify error handling for file-not-found

Make `Builder::sign(path, path, signer)` throw the same error type as `Reader(path)` for file-open failures. Both should use `std::system_error` or both should use `C2paException` wrapping the system error.

**Files**: `src/c2pa.cpp:1039-1042` vs `src/c2pa.cpp:681-683`

### R6. Replace `#include <iostream>` with targeted includes

In `include/c2pa.hpp`, replace `#include <iostream>` with `#include <istream>` and `#include <ostream>`. The `std::iostream` type is declared in `<istream>` on most implementations, but if needed, also include `<iosfwd>`.

### R7. Extract duplicated byte-buffer-from-C-API pattern

The pattern of "call C API, check null, copy to vector, free" appears 4 times (in `sign`, `data_hashed_placeholder`, `sign_data_hashed_embeddable`, `format_embeddable`). Extract a helper:

```cpp
namespace detail {
    inline std::vector<unsigned char> to_byte_vector(const unsigned char* data, int64_t size) {
        if (size < 0 || data == nullptr) {
            safe_c2pa_free(data);
            throw C2paException();
        }
        auto result = std::vector<unsigned char>(data, data + size);
        safe_c2pa_free(data);
        return result;
    }
}
```

**Files**: `src/c2pa.cpp:984-994`, `src/c2pa.cpp:1107-1117`, `src/c2pa.cpp:1132-1139`, `src/c2pa.cpp:1144-1153`

### R8. Deduplicate test fixture base classes

`BuilderTest` and `ReaderTest` have near-identical `get_temp_path()`, `get_temp_dir()`, and `TearDown()` implementations. Extract a shared `C2paTestBase` fixture class in `test_utils.hpp`.

**Files**: `tests/builder.test.cpp:32-83`, `tests/reader.test.cpp:25-52`

---

## Part 3: Third-Party Extensibility Recommendations

### Current Extensibility Points
- **`IContextProvider`**: Third parties can implement custom context providers
- **`SignerFunc` callback**: Third parties can provide custom signing logic
- **Stream wrappers**: Any `std::istream`/`std::ostream`/`std::iostream` can be adapted

### Gaps and Recommendations

#### E1. Add a validation/verification callback or listener interface

Currently, validation results are buried in the JSON output of `Reader::json()`. Third parties have no way to hook into the validation process programmatically. Consider:

```cpp
class IValidationListener {
public:
    virtual ~IValidationListener() = default;
    virtual void on_validation_result(const std::string& manifest_label,
                                      ValidationStatus status,
                                      const std::string& detail_json) = 0;
};
```

This would let third parties build custom trust UIs, logging, or enforcement policies without parsing JSON.

#### E2. Add a format/codec registration mechanism

`Reader::supported_mime_types()` and `Builder::supported_mime_types()` return fixed lists from the Rust layer. There's no way for third parties to add support for new media formats. If the Rust FFI supports it, expose a registration API:

```cpp
// Hypothetical - depends on Rust layer support
static void Reader::register_format(const std::string& mime_type, FormatHandler handler);
```

Even if the Rust layer doesn't support this today, documenting this as a future extensibility direction would be valuable.

#### E3. Expose a structured manifest API alongside raw JSON

All manifest data is returned as raw JSON strings. Third parties must parse this themselves (the tests all use `nlohmann/json`). Consider providing:

- A `ManifestStore` value type with typed accessors (active manifest, manifests list, validation state)
- Or at minimum, convenience methods like `Reader::active_manifest_label()`, `Reader::validation_state()`

This reduces the parsing burden and makes the API more discoverable. It also creates a stable programmatic interface that doesn't break when JSON structure changes.

#### E4. Add an error code enum to `C2paException`

Currently, `C2paException` only carries a string message. Third parties can't programmatically distinguish between error types without string parsing (see the `strstr(C2paException.what(), "ManifestNotFound")` pattern in `src/c2pa.cpp:508`). Adding an error code enum would make error handling robust:

```cpp
enum class C2paError {
    Unknown,
    ManifestNotFound,
    InvalidManifest,
    SigningFailed,
    IoError,
    UnsupportedFormat,
    // ...
};

class C2paException : public std::exception {
public:
    C2paError code() const noexcept;
    // ...
};
```

#### E5. Make Settings queryable

`Settings` can be created and updated, but not read back. Third parties building on top of the library (e.g., wrapping it in a GUI) need to display current settings. Add:

```cpp
std::string Settings::to_json() const;
std::optional<std::string> Settings::get(const std::string& path) const;
```

#### E6. Consider a plugin architecture for Signers

The current `SignerFunc` callback is a raw function pointer, which means it can't carry state (closures won't work unless you use `std::function`, which has a different ABI). Consider:

```cpp
class ISigner {
public:
    virtual ~ISigner() = default;
    virtual std::vector<unsigned char> sign(const std::vector<unsigned char>& data) = 0;
    virtual C2paSigningAlg algorithm() const = 0;
    virtual std::string certificate() const = 0;
    virtual std::optional<std::string> tsa_uri() const = 0;
    virtual uintptr_t reserve_size() const = 0;
};
```

This would let third parties implement signers that hold state (HSM connections, cloud KMS clients, etc.) cleanly via inheritance rather than through void pointer casts.

#### E7. Provide Builder inspection/serialization

Add `Builder::to_json()` to serialize the current manifest definition. This enables:
- Round-tripping: read a manifest, modify, re-sign
- Debugging: inspect what will be signed
- Third-party tooling: manifest editors, validators

---

## Verification

To verify any refactoring changes:

1. **Build**: `make debug` (or `cmake --build build`)
2. **Run tests**: `make test` (runs all C++ and C tests)
3. **Run with sanitizers**: `make test-san` (ASAN + UBSAN)
4. **Run examples**: `make examples` (training + demo)
5. **Check for regressions**: Ensure all existing tests pass unchanged
6. **API compatibility**: Verify no public header signatures changed (for non-breaking changes)
