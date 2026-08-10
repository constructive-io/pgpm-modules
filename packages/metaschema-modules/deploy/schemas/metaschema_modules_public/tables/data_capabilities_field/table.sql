-- Deploy schemas/metaschema_modules_public/tables/data_capabilities_field/table to pg

-- requires: schemas/metaschema_modules_public/schema
-- requires: schemas/metaschema_modules_public/tables/capabilities_module/table

BEGIN;

-- One row per DataCapabilities declaration — a schema usage, never a record.
--
-- The SPRT materializes what an actor holds; this registry marks the column
-- that materializes what a row requires, so a read is a flat bitwise subset
-- test (sprt.capabilities & row.required = row.required) with no join onto a
-- grant table.
--
-- Two set-level questions are answered here, and both are the reason the
-- declaration is recorded rather than inferred:
--
--   1. bitlen — widening a scope's capability mask must repad every row mask
--      and every mapping mask that feeds one, or the AND becomes a type error.
--   2. propagation — a derived mask is stamped from a mapping row, so a mask
--      change on the mapping table has to find the tables that copied it.
CREATE TABLE metaschema_modules_public.data_capabilities_field (
    id uuid PRIMARY KEY DEFAULT uuidv7(),
    database_id uuid NOT NULL,

    -- The protected table and its bit(bitlen) required-permissions column.
    table_id uuid NOT NULL,
    field_id uuid NOT NULL,

    -- The capability vocabulary the mask is written in. Names it explicitly:
    -- bitlen and capability names are per (scope, prefix), so a mask is only
    -- meaningful against one module.
    capabilities_module_id uuid NOT NULL,

    -- 'direct'  — the mask is written on the protected row.
    -- 'derived' — the mask is stamped from a mapping row (classification etc.).
    mode text NOT NULL DEFAULT 'direct',

    -- Derived mode only: the FK on the protected table, the mapping table it
    -- points into, the key column it points at, and the mapping table's own
    -- mask column that gets copied down.
    from_field_id uuid NULL,
    mapping_table_id uuid NULL,
    mapping_key_field_id uuid NULL,
    mapping_field_id uuid NULL,

    -- Direct mode only: writes are guarded so a writer cannot require a bit
    -- they do not themselves hold (new_mask & writer_mask = new_mask).
    subset_guard boolean NOT NULL DEFAULT true,

    CONSTRAINT db_fkey FOREIGN KEY (database_id) REFERENCES metaschema_public.database (id) ON DELETE CASCADE,
    CONSTRAINT table_fkey FOREIGN KEY (table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT field_fkey FOREIGN KEY (field_id) REFERENCES metaschema_public.field (id) ON DELETE CASCADE,
    CONSTRAINT capabilities_module_fkey FOREIGN KEY (capabilities_module_id) REFERENCES metaschema_modules_public.capabilities_module (id) ON DELETE CASCADE,
    CONSTRAINT from_field_fkey FOREIGN KEY (from_field_id) REFERENCES metaschema_public.field (id) ON DELETE CASCADE,
    CONSTRAINT mapping_table_fkey FOREIGN KEY (mapping_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT mapping_key_field_fkey FOREIGN KEY (mapping_key_field_id) REFERENCES metaschema_public.field (id) ON DELETE CASCADE,
    CONSTRAINT mapping_field_fkey FOREIGN KEY (mapping_field_id) REFERENCES metaschema_public.field (id) ON DELETE CASCADE,

    CONSTRAINT mode_chk CHECK (mode IN ('direct', 'derived')),

    -- Derived mode is the whole propagation path or none of it: a half-declared
    -- mapping stamps nothing and silently leaves rows at their default mask.
    CONSTRAINT derived_mode_chk CHECK (
        (mode = 'derived'
          AND from_field_id IS NOT NULL
          AND mapping_table_id IS NOT NULL
          AND mapping_key_field_id IS NOT NULL
          AND mapping_field_id IS NOT NULL)
        OR
        (mode = 'direct'
          AND from_field_id IS NULL
          AND mapping_table_id IS NULL
          AND mapping_key_field_id IS NULL
          AND mapping_field_id IS NULL)
    ),

    -- One mask column carries one row's requirement, so one row describes it.
    UNIQUE (field_id)
);

CREATE INDEX data_capabilities_field_database_id_idx ON metaschema_modules_public.data_capabilities_field ( database_id );
CREATE INDEX data_capabilities_field_table_id_idx ON metaschema_modules_public.data_capabilities_field ( table_id );

-- The bitlen migration asks "every row mask written in this module's vocabulary".
CREATE INDEX data_capabilities_field_capabilities_module_id_idx ON metaschema_modules_public.data_capabilities_field ( capabilities_module_id );

-- Restamping asks "which protected tables copied this mapping table's mask".
CREATE INDEX data_capabilities_field_mapping_table_id_idx ON metaschema_modules_public.data_capabilities_field ( mapping_table_id );

-- The derived-mode field references, so dropping a field does not scan this
-- table three times to find its cascades (field_id is covered by its UNIQUE).
CREATE INDEX data_capabilities_field_from_field_id_idx ON metaschema_modules_public.data_capabilities_field ( from_field_id );
CREATE INDEX data_capabilities_field_mapping_key_field_id_idx ON metaschema_modules_public.data_capabilities_field ( mapping_key_field_id );
CREATE INDEX data_capabilities_field_mapping_field_id_idx ON metaschema_modules_public.data_capabilities_field ( mapping_field_id );

COMMIT;
