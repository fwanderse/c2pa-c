# Configuring settings

You can configure SDK settings using a JSON configuration that controls many aspects of the library's behavior. This JSON definition works the same across C2PA SDK implementations (Rust, C/C++, and other language bindings like Python).

This document describes how to use settings in the C++ API and the available options. The schema is shared with the [C2PA Rust SDK](https://github.com/contentauth/c2pa-rs); for the complete JSON schema, see the [CAI settings schema reference](https://opensource.contentauthenticity.org/docs/manifest/json-ref/settings-schema/).

**NOTE:** If you don't specify a value for a property, the SDK uses the default value. If you specify a value of `null`, the property is set to `null`, not the default.

## Using settings with Context

**The recommended approach** is to use the `Context` API, which wraps settings and provides explicit configuration for `Reader` and `Builder`:

```cpp
#include "c2pa.hpp"

int main() {
    // Create a Context with settings from a string
    c2pa::Context context(R"({
        "verify": {"verify_after_sign": true},
        "builder": {"claim_generator_info": {"name": "My App"}}
    })");

    c2pa::Builder builder(context, manifest_json);
    // ... use builder
}
```

Or with a `Settings` object:

```cpp
// Create the object
c2pa::Settings settings;

// Configure settings
settings.update(R"({"verify": {"verify_after_sign": true}})");

// Create a context with settings
c2pa::Context context(settings);

// Use the context
c2pa::Builder builder(context, manifest_json);
```

The Context API:

- Makes configuration explicit (no global or thread-local state)
- Allows different configurations for different operations
- Ensures settings are applied consistently to `Reader` and `Builder`

**Legacy approach:** The deprecated `c2pa::load_settings(data, format)` sets thread-local settings. Prefer passing a `Context` (with settings) to `Reader` and `Builder` instead. See [context.md](context.md).

## Settings API (C++)

Create and configure settings:

| Method | Description |
|--------|-------------|
| `Settings()` | Default settings. |
| `Settings(data, format)` | Parse settings from a string. `format` is `"json"` or `"toml"`. Throws `C2paException` on parse error. |
| `set(path, json_value)` | Set one value by dot-separated path (e.g. `"verify.verify_after_sign"`). Value must be JSON-encoded. Returns `*this` for chaining. |
| `update(data)` | Merge configuration from a JSON string (same as `update(data, "json")`). Later keys override. |
| `update(data, format)` | Merge configuration from a string; `format` is `"json"`. TOML is supported here too. |
| `is_valid()` | `true` if the object holds a valid handle (e.g. not moved-from). |

Settings are **not copyable**; they are **moveable**. After move, the source's `is_valid()` is `false`.

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

### trust

Certificate trust for C2PA validation. Use PEM strings with `\n` for line breaks.

| Property | Type | Description | Default |
|----------|------|-------------|---------|
| `trust.user_anchors` | string | Additional user root certificates (PEM) | — |
| `trust.trust_anchors` | string | Default trust anchor roots (PEM) | — |
| `trust.trust_config` | string | Allowed EKU OIDs | — |
| `trust.allowed_list` | string | Explicitly allowed certificates (PEM) | — |

### cawg_trust

Configuration for CAWG (Creator Assertions Working Group) validation when using X.509. Structure matches `trust`.

| Property | Type | Description | Default |
|----------|------|-------------|---------|
| `cawg_trust.verify_trust_list` | boolean | Enforce CAWG trust list | true |
| `cawg_trust.user_anchors` | string | Additional roots (PEM) | — |
| `cawg_trust.trust_anchors` | string | Trust anchors (PEM) | — |
| `cawg_trust.trust_config` | string | Allowed EKU OIDs | — |
| `cawg_trust.allowed_list` | string | Allowed certificates (PEM) | — |

### core

Core behavior and performance.

| Property | Type | Description | Default |
|----------|------|-------------|---------|
| `core.merkle_tree_chunk_size_in_kb` | number | BMFF Merkle tree chunk size (KB) | — |
| `core.merkle_tree_max_proofs` | number | Max Merkle proofs when validating | 5 |
| `core.backing_store_memory_threshold_in_mb` | number | Memory threshold before disk (MB) | 512 |
| `core.decode_identity_assertions` | boolean | Decode CAWG identity assertions | true |
| `core.allowed_network_hosts` | array | Allowed network host patterns | — |

### verify

Verification behavior.

| Property | Type | Description | Default |
|----------|------|-------------|---------|
| `verify.verify_after_reading` | boolean | Verify after reading | true |
| `verify.verify_after_sign` | boolean | Verify after signing | true |
| `verify.verify_trust` | boolean | Verify certs against trust | true |
| `verify.verify_timestamp_trust` | boolean | Verify TSA certs | true |
| `verify.ocsp_fetch` | boolean | Fetch OCSP during validation | false |
| `verify.remote_manifest_fetch` | boolean | Fetch remote manifests | true |
| `verify.skip_ingredient_conflict_resolution` | boolean | Skip ingredient conflict resolution | false |
| `verify.strict_v1_validation` | boolean | Strict C2PA v1 validation | false |

**WARNING:** Setting any `verify.*` option from `true` to `false` can make verification non-compliant with the C2PA specification. Use only when necessary (e.g. controlled environments).

### builder

Builder behavior (claim generator, thumbnails, actions, etc.).

| Property | Type | Description | Default |
|----------|------|-------------|---------|
| `builder.claim_generator_info` | object | Default claim generator (see below) | — |
| `builder.thumbnail.enabled` | boolean | Enable thumbnails | true |
| `builder.thumbnail.ignore_errors` | boolean | Continue on thumbnail errors | true |
| `builder.thumbnail.long_edge` | number | Longest edge in pixels | 1024 |
| `builder.thumbnail.format` | string | `"jpeg"`, `"png"`, `"webp"`, or null | null |
| `builder.thumbnail.prefer_smallest_format` | boolean | Prefer smallest format | true |
| `builder.thumbnail.quality` | string | `"low"`, `"medium"`, `"high"` | `"medium"` |
| `builder.actions.auto_created_action.enabled` | boolean | Auto `c2pa.created` | true |
| `builder.actions.auto_created_action.source_type` | string | Source type for created | `"empty"` |
| `builder.actions.auto_opened_action.enabled` | boolean | Auto `c2pa.opened` | true |
| `builder.actions.auto_placed_action.enabled` | boolean | Auto `c2pa.placed` | true |
| `builder.intent` | object | e.g. `{"Create": "digitalCapture"}`, `"Edit"`, `"Update"` | null |
| `builder.generate_c2pa_archive` | boolean | Generate C2PA archive format | true |

**claim_generator_info** (when used): at least `name` (string). May include `version`, `icon`, `operating_system`, and custom fields.

### signer

Primary C2PA signer. Can be `null`, or a **local** or **remote** object.

**Local signer:**

| Property | Type | Description |
|----------|------|-------------|
| `signer.local.alg` | string | `"ps256"`, `"ps384"`, `"ps512"`, `"es256"`, `"es384"`, `"es512"`, `"ed25519"` |
| `signer.local.sign_cert` | string | Certificate chain (PEM) |
| `signer.local.private_key` | string | Private key (PEM) |
| `signer.local.tsa_url` | string | TSA URL (optional) |

**Remote signer:** `signer.remote` with `url`, `alg`, `sign_cert`, `tsa_url`. The service receives POST with the data to sign and returns the signature.

### cawg_x509_signer

CAWG X.509 signer for identity assertions. Same structure as `signer` (local or remote). When both `signer` and `cawg_x509_signer` are set, the SDK uses a dual signer: main claim signature from `signer`, identity assertions from `cawg_x509_signer`.

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

### Local signer (in settings)

```json
{
  "version": 1,
  "signer": {
    "local": {
      "alg": "ps256",
      "sign_cert": "-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----",
      "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----",
      "tsa_url": "http://timestamp.digicert.com"
    }
  },
  "builder": { "intent": {"Create": "digitalCapture"} }
}
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

- [Configuring the SDK using Context](context.md) — how to create and use contexts with settings.
- [Usage](usage.md) — reading and signing with `Reader` and `Builder`.
- [CAI settings schema](https://opensource.contentauthenticity.org/docs/manifest/json-ref/settings-schema/) — full schema reference.
