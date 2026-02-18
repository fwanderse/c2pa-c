# Configuring SDK settings

You can configure SDK settings using a JSON configuration that controls many aspects of the library's behavior. This JSON definition works the same across languages (Rust, C/C++, and other language bindings like Python).

This document describes how to use settings in the C++ API and the available options. The schema is shared with the [C2PA Rust library](https://github.com/contentauth/c2pa-rs); for the complete JSON schema, see the [CAI settings schema reference](https://opensource.contentauthenticity.org/docs/manifest/json-ref/settings-schema/).

**IMPORTANT:** If you don't specify a value for a property, the SDK uses the default value. If you specify a value of `null`, the property is explicitly set to `null`, not the default. This distinction is important when you want to override a default behavior.

## Using settings with Context

**The recommended approach** is to use the `Context` API, which wraps settings and provides explicit configuration for `Reader` and `Builder`. This approach:

- Makes configuration explicit (no global or thread-local state)
- Allows different configurations for different operations
- Ensures settings are applied consistently to `Reader` and `Builder`
- Copies context state at construction, so the context doesn't need to outlive the reader/builder

### Quick start: Direct construction with JSON

The simplest way to create a context with settings is to pass a JSON string directly:

```cpp
#include "c2pa.hpp"

int main() {
    // Create a context with settings from a JSON string
    c2pa::Context context(R"({
        "version": 1,
        "verify": {"verify_after_sign": true},
        "builder": {"claim_generator_info": {"name": "My App", "version": "1.0.0"}}
    })");

    // Use the context object with Builder
    c2pa::Builder builder(context, manifest_json);
    // ... use builder
}
```

### Programmatic configuration with Settings

For more control, use a `Settings` object to configure settings programmatically:

```cpp
// Create a Settings object
c2pa::Settings settings;

// Configure individual settings using dot notation
settings.set("builder.thumbnail.enabled", "false");
settings.set("verify.verify_after_sign", "true");

// Or merge JSON configuration (later settings override earlier ones)
settings.update(R"({
    "builder": {
        "claim_generator_info": {"name": "My App", "version": "1.0.0"}
    }
})");

// Create a context with the configured settings
c2pa::Context context(settings);

// Use the context
c2pa::Builder builder(context, manifest_json);
```

### Using ContextBuilder for advanced scenarios

For complex configurations or when loading settings from files, use `ContextBuilder`:

```cpp
// Build a context step by step
auto context = c2pa::Context::ContextBuilder()
    .with_json_settings_file("/path/to/settings.json")
    .with_json(R"({"builder": {"thumbnail": {"enabled": false}}})")
    .create_context();

// Or combine Settings objects with JSON (later calls override earlier ones)
c2pa::Settings base_settings;
base_settings.set("builder.thumbnail.long_edge", "512");

auto context = c2pa::Context::ContextBuilder()
    .with_settings(base_settings)
    .with_json(R"({"verify": {"verify_after_sign": true}})")
    .create_context();
```

**Legacy approach:** The deprecated `c2pa::load_settings(data, format)` sets thread-local settings. Prefer passing a `Context` (with settings) to `Reader` and `Builder` instead. See [context.md](context.md).

## Settings API (C++)

Create and configure settings:

| Method | Description |
|--------|-------------|
| `Settings()` | Create default settings with SDK defaults. |
| `Settings(data, format)` | Parse settings from a string. `format` is `"json"` or `"toml"`. Throws `C2paException` on parse error. |
| `set(path, json_value)` | Set a single value by dot-separated path (e.g. `"verify.verify_after_sign"`). Value must be JSON-encoded. Returns `*this` for chaining. Use this for programmatic configuration. |
| `update(data)` | Merge JSON configuration into existing settings (same as `update(data, "json")`). Later keys override earlier ones. Use this to apply configuration files or JSON strings. |
| `update(data, format)` | Merge configuration from a string; `format` is `"json"` or `"toml"`. |
| `is_valid()` | Returns `true` if the object holds a valid handle (e.g. not moved-from). |

**Important notes:**

- Settings are **not copyable**; they are **moveable**. After move, the source's `is_valid()` is `false`.
- The `set()` and `update()` methods can be chained for sequential configuration.
- When using multiple configuration methods, later calls override earlier ones (last wins).

## Overview of the configuration structure

The configuration JSON has this top-level structure:

```json
{
  "version": 1,
  "trust": { ... },
  "cawg_trust": { ... },
  "core": { ... },
  "verify": { ... },
  "builder": { ... },
  "signer": { ... },
  "cawg_x509_signer": { ... }
}
```

### Settings format

Settings can be provided in **JSON** or **TOML**. Use `Settings(data, format)` with `"json"` or `"toml"`, or pass JSON to `Context(json_string)` / `ContextBuilder::with_json()`. JSON is preferred for settings in the C++ SDK.

```cpp
// JSON
c2pa::Settings settings(R"({"verify": {"verify_after_sign": true}})", "json");

// TOML
c2pa::Settings settings(R"(
    [verify]
    verify_after_sign = true
)", "toml");

// Context from JSON string
c2pa::Context context(R"({"verify": {"verify_after_sign": true}})");
```

To load from a file, read the file contents into a string and pass to `Settings` or use `Context::ContextBuilder::with_json_settings_file(path)`.

## Complete default configuration

Below is the JSON structure with typical default values. Omitted properties use SDK defaults; setting a property to `null` explicitly sets it to `null`.

```json
{
  "version": 1,
  "trust": {
    "user_anchors": null,
    "trust_anchors": null,
    "trust_config": null,
    "allowed_list": null
  },
  "cawg_trust": {
    "verify_trust_list": true,
    "user_anchors": null,
    "trust_anchors": null,
    "trust_config": null,
    "allowed_list": null
  },
  "core": {
    "merkle_tree_chunk_size_in_kb": null,
    "merkle_tree_max_proofs": 5,
    "backing_store_memory_threshold_in_mb": 512,
    "decode_identity_assertions": true,
    "allowed_network_hosts": null
  },
  "verify": {
    "verify_after_reading": true,
    "verify_after_sign": true,
    "verify_trust": true,
    "verify_timestamp_trust": true,
    "ocsp_fetch": false,
    "remote_manifest_fetch": true,
    "skip_ingredient_conflict_resolution": false,
    "strict_v1_validation": false
  },
  "builder": {
    "claim_generator_info": null,
    "thumbnail": {
      "enabled": true,
      "ignore_errors": true,
      "long_edge": 1024,
      "format": null,
      "prefer_smallest_format": true,
      "quality": "medium"
    },
    "actions": {
      "all_actions_included": null,
      "templates": null,
      "actions": null,
      "auto_created_action": { "enabled": true, "source_type": "empty" },
      "auto_opened_action": { "enabled": true, "source_type": null },
      "auto_placed_action": { "enabled": true, "source_type": null }
    },
    "certificate_status_fetch": null,
    "certificate_status_should_override": null,
    "intent": null,
    "created_assertion_labels": null,
    "generate_c2pa_archive": true
  },
  "signer": null,
  "cawg_x509_signer": null
}
```

## Property reference

The top-level **`version`** must be `1`. All other properties are optional.

- **Unspecified**: SDK uses its default.
- **Set to `null`**: property is `null`, not the default.
- Use JSON booleans (`true` / `false`), not the strings `"true"` / `"false"`.

### Trust configuration

Certificate trust configuration for C2PA validation. These settings control which certificates are trusted when validating C2PA manifests.

| Property | Type | Description | Default |
|----------|------|-------------|---------|
| `trust.user_anchors` | string | Additional user-provided root certificates (PEM format). Adds custom certificate authorities without replacing the SDK's built-in trust anchors. | — |
| `trust.trust_anchors` | string | Default trust anchor root certificates (PEM format). **Replaces** the SDK's built-in trust anchors entirely. | — |
| `trust.trust_config` | string | Allowed Extended Key Usage (EKU) OIDs. Controls which certificate purposes are accepted (e.g., document signing: `1.3.6.1.4.1.311.76.59.1.9`). | — |
| `trust.allowed_list` | string | Explicitly allowed certificates (PEM format). These certificates are trusted regardless of chain validation. Use for development/testing. | — |

#### Configuring trust for development and testing

When using self-signed certificates or custom certificate authorities during development, you need to configure trust settings so the SDK can validate your test signatures.

##### Option 1: Using `user_anchors` (recommended for development)

Add your test root CA to the trusted anchors without replacing the SDK's default trust store:

```cpp
// Read your test root CA certificate
std::string test_root_ca = R"(-----BEGIN CERTIFICATE-----
MIICEzCCAcWgAwIBAgIUW4fUnS38162x10PCnB8qFsrQuZgwBQYDK2VwMHcxCzAJ
...
-----END CERTIFICATE-----)";

c2pa::Context context(R"({
    "version": 1,
    "trust": {
        "user_anchors": ")" + test_root_ca + R"("
    }
})");

c2pa::Reader reader(context, "signed_asset.jpg");
```

##### Option 2: Using `allowed_list` (bypass chain validation)

For quick testing, explicitly allow a specific certificate without validating the chain:

```cpp
// Read your test signing certificate
std::string test_cert = read_file("test_cert.pem");

c2pa::Settings settings;
settings.update(R"({
    "version": 1,
    "trust": {
        "allowed_list": ")" + test_cert + R"("
    }
})");

c2pa::Context context(settings);
c2pa::Reader reader(context, "signed_asset.jpg");
```

##### Option 3: Loading from a configuration file

For team development, store trust configuration in a file:

```json
{
  "version": 1,
  "trust": {
    "user_anchors": "-----BEGIN CERTIFICATE-----\nMIICEzCCA...\n-----END CERTIFICATE-----",
    "trust_config": "1.3.6.1.4.1.311.76.59.1.9\n1.3.6.1.4.1.62558.2.1"
  }
}
```

Then load it in your application:

```cpp
auto context = c2pa::Context::ContextBuilder()
    .with_json_settings_file("dev_trust_config.json")
    .create_context();

c2pa::Reader reader(context, "signed_asset.jpg");
```

**PEM format requirements:**

- Use literal `\n` characters (as two-character strings) in JSON for line breaks
- Include the full certificate chain if needed
- Multiple certificates can be concatenated in a single string

### cawg_trust

Configuration for CAWG (Creator Assertions Working Group) validation when using X.509 certificates. This is used when validating identity assertions in C2PA manifests. The structure matches the `trust` section.

| Property | Type | Description | Default |
|----------|------|-------------|---------|
| `cawg_trust.verify_trust_list` | boolean | Enforce CAWG trust list validation. Set to `false` to skip CAWG-specific trust checks (not recommended for production). | `true` |
| `cawg_trust.user_anchors` | string | Additional root certificates (PEM format) for CAWG identity validation. | — |
| `cawg_trust.trust_anchors` | string | Trust anchor certificates (PEM format). Replaces default CAWG trust anchors. | — |
| `cawg_trust.trust_config` | string | Allowed Extended Key Usage OIDs for CAWG certificates. | — |
| `cawg_trust.allowed_list` | string | Explicitly allowed CAWG certificates (PEM format). | — |

**Note:** CAWG trust settings are only used when processing identity assertions with X.509 certificates. If your workflow doesn't use CAWG identity assertions, these settings have no effect.

### core

Core SDK behavior and performance tuning options.

| Property | Type | Description | Default |
|----------|------|-------------|---------|
| `core.merkle_tree_chunk_size_in_kb` | number | Chunk size in KB for BMFF (ISO Base Media File Format) Merkle tree generation. Larger chunks reduce overhead but increase memory usage. | — |
| `core.merkle_tree_max_proofs` | number | Maximum number of Merkle proofs to validate. Set lower to improve performance, higher to increase validation thoroughness. | `5` |
| `core.backing_store_memory_threshold_in_mb` | number | Memory threshold in MB before the SDK switches to disk-based storage for large files. Increase for better performance with large assets if you have sufficient RAM. | `512` |
| `core.decode_identity_assertions` | boolean | Decode CAWG identity assertions during manifest reading. Set to `false` to skip decoding if you don't use identity assertions. | `true` |
| `core.allowed_network_hosts` | array | Allowed network host patterns for remote operations (e.g., fetching remote manifests, OCSP). Use to restrict network access in sandboxed environments. | — |

**Use cases:**

- **Performance tuning for large files:** Increase `backing_store_memory_threshold_in_mb` to `2048` or higher if processing large video files with sufficient RAM.
- **Restricted network environments:** Set `allowed_network_hosts` to limit which domains the SDK can contact.

### verify

Verification behavior settings control how the SDK validates C2PA manifests. These settings affect both reading existing manifests and verifying newly signed content.

| Property | Type | Description | Default |
|----------|------|-------------|---------|
| `verify.verify_after_reading` | boolean | Automatically verify manifests when reading assets. Disable only if you want to manually control verification timing. | `true` |
| `verify.verify_after_sign` | boolean | Automatically verify manifests after signing. Recommended to keep enabled to catch signing errors immediately. | `true` |
| `verify.verify_trust` | boolean | Verify signing certificates against configured trust anchors. **Disabling makes verification non-compliant.** | `true` |
| `verify.verify_timestamp_trust` | boolean | Verify timestamp authority (TSA) certificates. **Disabling makes verification non-compliant.** | `true` |
| `verify.ocsp_fetch` | boolean | Fetch OCSP (Online Certificate Status Protocol) responses during validation to check certificate revocation status. Requires network access. | `false` |
| `verify.remote_manifest_fetch` | boolean | Fetch remote manifests referenced in the asset. Disable in offline or air-gapped environments. | `true` |
| `verify.skip_ingredient_conflict_resolution` | boolean | Skip automatic resolution of ingredient conflicts in the manifest chain. Advanced use only. | `false` |
| `verify.strict_v1_validation` | boolean | Enable strict C2PA v1 specification validation. Use for compliance testing or when strict adherence is required. | `false` |

**WARNING:** Disabling verification options (changing `true` to `false`) can make verification non-compliant with the C2PA specification. Only modify these settings in controlled environments or when you have specific requirements.

**Use cases:**

#### Offline/air-gapped environments

Disable network-dependent verification features:

```cpp
c2pa::Context context(R"({
    "version": 1,
    "verify": {
        "remote_manifest_fetch": false,
        "ocsp_fetch": false
    }
})");

c2pa::Reader reader(context, "signed_asset.jpg");
```

#### Fast development iteration (verification disabled)

During active development, you might want to skip verification for faster iteration:

```cpp
// WARNING: Only use during development, not in production!
c2pa::Settings dev_settings;
dev_settings.set("verify.verify_after_reading", "false");
dev_settings.set("verify.verify_after_sign", "false");

c2pa::Context dev_context(dev_settings);
```

#### Strict compliance validation

For certification or compliance testing, enable strict validation:

```cpp
c2pa::Context context(R"({
    "version": 1,
    "verify": {
        "strict_v1_validation": true,
        "ocsp_fetch": true,
        "verify_trust": true,
        "verify_timestamp_trust": true
    }
})");

c2pa::Reader reader(context, "asset_to_validate.jpg");
auto validation_result = reader.json();
```

### builder

Builder behavior settings control how the SDK creates and embeds C2PA manifests in assets.

#### Claim generator information

| Property | Type | Description | Default |
|----------|------|-------------|---------|
| `builder.claim_generator_info` | object | Information about the tool that generated the claim. Should include at minimum `name` and `version`. | — |

The `claim_generator_info` object identifies your application in the C2PA manifest. **Recommended fields:**

- `name` (string, required): Your application name (e.g., `"My Photo Editor"`)
- `version` (string, recommended): Application version (e.g., `"2.1.0"`)
- `icon` (string, optional): Icon in C2PA format
- `operating_system` (string, optional): OS identifier or `"auto"` to auto-detect

**Example:**

```cpp
c2pa::Context context(R"({
    "version": 1,
    "builder": {
        "claim_generator_info": {
            "name": "My Photo Editor",
            "version": "2.1.0",
            "operating_system": "auto"
        }
    }
})");
```

#### Thumbnail settings

| Property | Type | Description | Default |
|----------|------|-------------|---------|
| `builder.thumbnail.enabled` | boolean | Generate and embed thumbnails in the manifest. Disable to reduce manifest size. | `true` |
| `builder.thumbnail.ignore_errors` | boolean | Continue signing even if thumbnail generation fails. Recommended for robustness. | `true` |
| `builder.thumbnail.long_edge` | number | Maximum size in pixels for the longest edge of the thumbnail. Common values: `512`, `1024`, `2048`. | `1024` |
| `builder.thumbnail.format` | string | Force specific format: `"jpeg"`, `"png"`, `"webp"`, or `null` for auto-select. | `null` |
| `builder.thumbnail.prefer_smallest_format` | boolean | Choose the format with the smallest file size. Recommended for bandwidth optimization. | `true` |
| `builder.thumbnail.quality` | string | Thumbnail quality: `"low"`, `"medium"`, or `"high"`. Affects file size vs. visual quality trade-off. | `"medium"` |

##### Use case: Optimize for mobile bandwidth**

```cpp
c2pa::Context context(R"({
    "version": 1,
    "builder": {
        "thumbnail": {
            "enabled": true,
            "long_edge": 512,
            "quality": "low",
            "prefer_smallest_format": true
        }
    }
})");
```

##### Use case: Disable thumbnails for batch processing**

```cpp
c2pa::Settings settings;
settings.set("builder.thumbnail.enabled", "false");
c2pa::Context context(settings);
// Faster signing, smaller manifests
```

#### Action tracking settings

| Property | Type | Description | Default |
|----------|------|-------------|---------|
| `builder.actions.auto_created_action.enabled` | boolean | Automatically add a `c2pa.created` action when creating new content. | `true` |
| `builder.actions.auto_created_action.source_type` | string | Source type for the created action. Usually `"empty"` for new content. | `"empty"` |
| `builder.actions.auto_opened_action.enabled` | boolean | Automatically add a `c2pa.opened` action when opening/reading content. | `true` |
| `builder.actions.auto_placed_action.enabled` | boolean | Automatically add a `c2pa.placed` action when placing content as an ingredient. | `true` |

#### Other builder settings

| Property | Type | Description | Default |
|----------|------|-------------|---------|
| `builder.intent` | object | Claim intent: `{"Create": "digitalCapture"}`, `{"Edit": null}`, or `{"Update": null}`. Describes the purpose of the claim. | `null` |
| `builder.generate_c2pa_archive` | boolean | Generate content in C2PA archive format. Keep enabled for standard C2PA compliance. | `true` |

##### Use case: Setting intent for different workflows**

```cpp
// For original digital capture (photos from camera)
c2pa::Context camera_context(R"({
    "version": 1,
    "builder": {
        "intent": {"Create": "digitalCapture"},
        "claim_generator_info": {"name": "Camera App", "version": "1.0"}
    }
})");

// For editing existing content
c2pa::Context editor_context(R"({
    "version": 1,
    "builder": {
        "intent": {"Edit": null},
        "claim_generator_info": {"name": "Photo Editor", "version": "2.0"}
    }
})");
```

### signer

The primary C2PA signer configuration. This can be `null` (if you provide the signer at runtime), or configured as either a **local** or **remote** signer in settings.

**Note:** While you can configure the signer in settings, the typical approach is to pass a `Signer` object directly to the `Builder.sign()` method. Use settings-based signing when you need the same signing configuration across multiple operations or when loading configuration from files.

#### Local signer

Use a local signer when you have direct access to the private key and certificate.

| Property  | Type  | Description  |
|-----------|-------|--------------|
| `signer.local.alg` | string | Signing algorithm: `"ps256"`, `"ps384"`, `"ps512"` (RSA-PSS), `"es256"`, `"es384"`, `"es512"` (ECDSA), or `"ed25519"` (EdDSA) |
| `signer.local.sign_cert`   | string | Certificate chain in PEM format. Include intermediate certificates if needed.  |
| `signer.local.private_key` | string | Private key in PEM format. **Keep this secure!**   |
| `signer.local.tsa_url`  | string | (Optional) Timestamp Authority URL for trusted timestamps (e.g., `"http://timestamp.digicert.com"`).  |

##### Example: Local signer with ES256**

```cpp
std::string config = R"({
    "version": 1,
    "signer": {
        "local": {
            "alg": "es256",
            "sign_cert": "-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----",
            "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----",
            "tsa_url": "http://timestamp.digicert.com"
        }
    }
})";

c2pa::Context context(config);
c2pa::Builder builder(context, manifest_json);
// Signer is already configured in context
builder.sign(source_path, dest_path);
```

#### Remote signer

Use a remote signer when the private key is stored on a secure signing service (HSM, cloud KMS, etc.).

| Property | Type   | Description  |
|----------|--------|--------------|
| `signer.remote.url` | string | URL of the remote signing service. The SDK will POST signing requests.  |
| `signer.remote.alg` | string | Signing algorithm (same values as local signer). |
| `signer.remote.sign_cert` | string | Certificate chain in PEM format.  |
| `signer.remote.tsa_url`  | string | (Optional) Timestamp Authority URL. |

The remote signing service receives a POST request with the data to sign and must return the signature in the expected format.

##### Example: Remote signer**

```cpp
c2pa::Context context(R"({
    "version": 1,
    "signer": {
        "remote": {
            "url": "https://signing-service.example.com/sign",
            "alg": "ps256",
            "sign_cert": "-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----",
            "tsa_url": "http://timestamp.digicert.com"
        }
    }
})");
```

### cawg_x509_signer

CAWG X.509 signer configuration for identity assertions. This has the same structure as `signer` (can be local or remote).

**When to use:** If you need to sign identity assertions separately from the main C2PA claim. When both `signer` and `cawg_x509_signer` are configured, the SDK uses a dual signer:

- Main claim signature comes from `signer`
- Identity assertions are signed with `cawg_x509_signer`

#### Example: Dual signer configuration**

```cpp
c2pa::Context context(R"({
    "version": 1,
    "signer": {
        "local": {
            "alg": "es256",
            "sign_cert": "...",
            "private_key": "..."
        }
    },
    "cawg_x509_signer": {
        "local": {
            "alg": "ps256",
            "sign_cert": "...",
            "private_key": "..."
        }
    }
})");
```

## Examples

### Minimal configuration

```json
{
  "version": 1,
  "builder": {
    "claim_generator_info": { "name": "my app", "version": "0.1.0" },
    "intent": {"Create": "digitalCapture"}
  }
}
```

```cpp
c2pa::Context context(R"({
  "version": 1,
  "builder": {
    "claim_generator_info": {"name": "my app", "version": "0.1.0"},
    "intent": {"Create": "digitalCapture"}
  }
})");
```

### Programmatic overrides

```cpp
c2pa::Settings settings;
settings.set("builder.thumbnail.enabled", "false");
settings.set("verify.verify_after_sign", "true");
c2pa::Context context(settings);
```

### No thumbnails

```json
{
  "version": 1,
  "builder": {
    "thumbnail": { "enabled": false }
  }
}
```

## See also

- [Configuring the SDK using Context](context.md): how to create and use contexts with settings.
- [Usage](usage.md): reading and signing with `Reader` and `Builder`.
- [CAI settings schema](https://opensource.contentauthenticity.org/docs/manifest/json-ref/settings-schema/): full schema reference.
