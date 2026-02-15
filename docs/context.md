# Configuring the SDK using Context

Use the `Context` class to configure the C2PA C++ library. Context holds the configuration and settings used by `Reader` and `Builder` for verification, signing, and manifest handling.

## What is Context?

Context encapsulates the configuration needed for C2PA operations:

- **Settings**: Verification options, builder behavior, trust anchors, signer configuration, and related options. Details on supported settings are found in [CAI settings schema reference](https://opensource.contentauthenticity.org/docs/manifest/json-ref/settings-schema/).
- **Signers**: When signer configuration is present in settings, the SDK can create signers from the context when needed for signing.

Context is preferred over the older global/thread-local settings because it:

- Makes dependencies explicit (configuration is passed in, not hidden).
- Allows multiple configurations in the same application (e.g. one context for dev, one for prod).
- No thread-local state: each Reader/Builder gets its configuration from the context you pass.
- Simplifies testing (different contexts per test).

The deprecated `c2pa::load_settings(data, format)` still works for backward compatibility but is not recommended. Prefer creating a `Context` with settings and passing it to `Reader` and `Builder`. See [Migration from load_settings](#migration-from-load_settings).

## Creating a Context

### Default context

```cpp
#include "c2pa.hpp"

c2pa::Context context;
```

### From a JSON string

```cpp
c2pa::Context context(R"({
  "verify": {"verify_after_sign": true},
  "builder": {"thumbnail": {"enabled": false}}
})");
```

### From a Settings object

```cpp
c2pa::Settings settings;
settings.update(R"({"verify": {"verify_after_sign": true}}");

c2pa::Context context(settings);
```

### Using ContextBuilder (multiple sources)

When you need to layer several configuration sources (e.g. base settings plus overrides), use `Context::ContextBuilder`:

```cpp
c2pa::Settings base_settings;
base_settings.set("builder.thumbnail.enabled", "true");

auto context = c2pa::Context::ContextBuilder()
    .with_settings(base_settings)
    .with_json(R"({"verify": {"verify_after_sign": true}})")
    .create_context();
```

Options:

- **`with_settings(settings)`** — Apply a `Settings` object (must be valid).
- **`with_json(json)`** — Apply settings from a JSON string. Later calls override earlier ones.
- **`with_json_settings_file(path)`** — Load JSON from a file and apply it.

Call **`create_context()`** to build the `Context`. The builder is consumed and must not be used afterward (`is_valid()` will be false).

For a single configuration source, direct construction (`Context()`, `Context(settings)`, `Context(json)`) is simpler.

## Configuring settings

You can configure settings in several ways:

### From a JSON string

```cpp
c2pa::Context context(R"({
  "verify": {"verify_after_sign": true},
  "builder": {"claim_generator_info": {"name": "My App"}}
})");
`````

### From a Settings object

```cpp
c2pa::Settings settings;
settings.set("builder.thumbnail.enabled", "false");
settings.update(R"({"verify": {"remote_manifest_fetch": false}})");

c2pa::Context context(settings);
```

### From a settings file

```cpp
auto context = c2pa::Context::ContextBuilder()
    .with_json_settings_file("/path/to/settings.json")
    .create_context();
```

For the full list of settings and defaults, see [Configuring settings](settings.md).

## Using Context with Reader

`Reader` uses the context to decide how to validate manifests and handle remote resources:

```cpp
// Context that disables remote manifest fetch
c2pa::Context context(R"({"verify": {"remote_manifest_fetch": false}})");

std::ifstream stream("image.jpg", std::ios::binary);
c2pa::Reader reader(context, "image/jpeg", stream);

std::cout << reader.json() << std::endl;
```

Or from a file path:

```cpp
c2pa::Reader reader(context, "image.jpg");
```

The context is used only at construction; the reader copies the configuration it needs. The context object does not need to outlive the reader.

## Using Context with Builder

`Builder` uses the context for signing and manifest creation. If settings include signer configuration, the signer is created from the context when you sign:

```cpp
c2pa::Context context(R"({
  "builder": {
    "claim_generator_info": {"name": "My App"},
    "intent": {"Create": "digitalCapture"}
  }
})");

c2pa::Builder builder(context, manifest_json);

// If signer is configured in context/settings, signing uses it
builder.sign(source_path, output_path, signer);
```

You can still pass an explicit `Signer` to `Builder::sign()`. The context mainly supplies verification and builder options (thumbnails, actions, etc.) and, when configured in settings, signer credentials.

The context is used only when constructing the builder; it does not need to outlive the builder.

## Configuring a signer

### From settings

Put signer configuration in your JSON or `Settings`, then create a context and use it with `Builder`:

```json
{
  "signer": {
    "local": {
      "alg": "ps256",
      "sign_cert": "path/to/cert.pem",
      "private_key": "path/to/key.pem",
      "tsa_url": "http://timestamp.example.com"
    }
  }
}
```

```cpp
c2pa::Context context(settings_json_or_path);
c2pa::Builder builder(context, manifest_json);
// When you call sign(), use a Signer created from your cert/key,
// or the SDK may use the signer from context if the C API supports it.
builder.sign(source_path, dest_path, signer);
```

In the C++ API you typically create a `c2pa::Signer` explicitly and pass it to `Builder::sign()`. Settings in the context still control verification, thumbnails, and other builder behavior. Check the [C2PA C API](https://github.com/contentauth/c2pa-rs) and [usage](usage.md) for how signer settings in the context are used when no explicit signer is passed (if supported).

### Explicit Signer

For full control (e.g. HSM or custom signing), create a `Signer` and pass it to `Builder::sign()`:

```cpp
c2pa::Signer signer("es256", certs_pem, private_key_pem, "http://timestamp.digicert.com");
c2pa::Builder builder(context, manifest_json);
builder.sign(source_path, dest_path, signer);
```

The context continues to control verification and builder options; the signer is used only for the cryptographic signature.

### Signer configuration in settings

The `signer` field in settings can be:

**Local signer** — certificate and key (paths or PEM strings):

- `signer.local.alg` — e.g. `"ps256"`, `"es256"`, `"ed25519"`.
- `signer.local.sign_cert` — certificate file path or PEM string.
- `signer.local.private_key` — key file path or PEM string.
- `signer.local.tsa_url` — optional TSA URL.

**Remote signer** — POST endpoint that receives data to sign and returns the signature:

- `signer.remote.url` — signing service URL.
- `signer.remote.alg`, `signer.remote.sign_cert`, `signer.remote.tsa_url`.

See [settings.md](settings.md) for the full property reference.

## Context lifetime and usage

- **Non-copyable, moveable:** Context can be moved; it is not copyable.
- **Reader/Builder only use it at construction:** After you create a `Reader` or `Builder` with a context, the implementation copies what it needs. The context object does not need to outlive the reader or builder.
- **Reuse:** You can reuse the same context to create multiple readers and builders.

```cpp
c2pa::Context context(settings);

c2pa::Builder builder1(context, manifest1);
c2pa::Builder builder2(context, manifest2);
c2pa::Reader reader(context, "image.jpg");
```

- **Different configs:** Use different contexts when you need different settings (e.g. one with trust for production, one without for tests).

```cpp
c2pa::Context dev_context(dev_settings);
c2pa::Context prod_context(prod_settings);

c2pa::Builder dev_builder(dev_context, manifest);
c2pa::Builder prod_builder(prod_context, manifest);
```

## When to use ContextBuilder

Use **direct construction** when you have a single source of configuration:

- `Context()`
- `Context(settings)`
- `Context(json_string)`

Use **ContextBuilder** when you want to:

- Combine a base `Settings` with JSON overrides.
- Load from a file with `with_json_settings_file()`.
- Apply several JSON snippets in order (later overrides earlier).

## Migration from load_settings

The legacy function `c2pa::load_settings(data, format)` sets thread-local settings. New code should use Context instead.

| Aspect | load_settings (legacy) | Context |
|--------|------------------------|---------|
| Scope | Global / thread-local | Per Reader/Builder, passed explicitly |
| Multiple configs | Awkward (per-thread) | One context per configuration |
| Testing | Shared global state | Isolated contexts per test |

**Deprecated:**

```cpp
// Thread-local settings
std::ifstream config_file("settings.json");
std::string config((std::istreambuf_iterator<char>(config_file)), std::istreambuf_iterator<char>());
c2pa::load_settings(config, "json");
c2pa::Reader reader("image/jpeg", stream);  // uses thread-local settings
```

**Using current APIs:**

```cpp
c2pa::Context context(settings_json_string);  // or Context(Settings(...))
c2pa::Reader reader(context, "image/jpeg", stream);
```

If you still use `load_settings`, construct `Reader` or `Builder` **without** a context to use the thread-local settings (see [usage.md](usage.md)). Prefer passing a context for new code.

## See also

- [Configuring settings](settings.md) — schema, property reference, and examples.
- [Usage](usage.md) — reading and signing with Reader and Builder.
