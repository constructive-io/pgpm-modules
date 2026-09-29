# @pgpm/db-utils

General database utility functions for PostgreSQL, deployed into the `db_utils` schema.

## Functions

- `db_utils.jsonb_deep_merge(a jsonb, b jsonb)` — recursive object merge; `b` wins on scalar conflicts.
- `db_utils.jsonb_set_deep(...)` — set a value at a nested path, creating intermediate objects.
- `db_utils.get_column_smart_comment(...)` — read a column's smart-comment metadata.
- timestamp helpers (`schemas/db_utils/procedures/timestamps`).

## Installation

```bash
pgpm install @pgpm/db-utils
pgpm deploy
```

## Testing

```bash
pnpm test
```
