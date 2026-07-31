# @pgpm/infra-utils

Typed parameter interface ("digital asset" interface) for infrastructure resource
bundles, evaluated entirely in PostgreSQL.

A bundle declares its parameters — `key`, `type` (`int` / `text` / `bool` /
`enum` / `quantity`), `default`, `required`, `min` / `max`, `options`, plus UI
metadata — and each declaration binds to explicit spec paths on explicit bundle
members:

```json
{
  "key": "heap_mb",
  "type": "int",
  "default": 3072,
  "min": 512,
  "max": 16384,
  "bindings": [
    { "path": "settings.NODE_OPTIONS", "template": "--max-old-space-size={{value}}" },
    { "path": "resources.limits.memory", "scale": 1.3333333, "round": "ceil", "unit": "Mi" }
  ]
}
```

`infra_utils.compile_resource_spec()` turns declared values into a compiled
JSONB resource spec by writing only to declared binding paths, so an unknown or
out-of-range parameter fails loudly instead of merging arbitrary JSON into a
spec. Compilation is a pure SQL function: no job queue, no worker, and it runs
in the same transaction as the install / upgrade / rollback that triggered it.

`infra_utils.quantity_to_numeric()` parses Kubernetes quantity strings
(`500m`, `4Gi`, `1.5G`) for bound checks and derived bindings.
