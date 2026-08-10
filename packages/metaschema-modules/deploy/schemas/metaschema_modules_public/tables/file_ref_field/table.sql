-- Deploy schemas/metaschema_modules_public/tables/file_ref_field/table to pg

-- requires: schemas/metaschema_modules_public/schema
-- requires: schemas/metaschema_modules_public/tables/storage_module/table

BEGIN;

-- One row per file-ref field declaration — a schema usage, never a record.
--
-- An upload/image column is a projection of a files row: the doc carries
-- {id, key, mime, bucket_id, ...} copied from it, so a read needs no join. This
-- table is the registry that makes the projection maintainable, and it answers
-- the three set-level questions the storage lane asks:
--
--   1. upload  — which bucket does a write to this column land in?
--   2. sync    — when a files row changes, which columns project it?
--   3. gc      — before deleting an object, which columns still refer to it?
--
-- storage_module_id is the load-bearing column. Module identity is
-- (database_id, scope, prefix), and a logical bucket key is owner-local: an
-- entity-scoped module has one 'avatars' bucket per entity row. So the module is
-- named at declaration time, and the physical bucket is resolved per written row
-- from the module's scope plus the row's own scope key. It also identifies the
-- files table a doc's id points into — there is no single global files table, so
-- a bare uuid in a document is unresolvable without it.
--
-- Intent is stored, never a bucket_id: at declaration time there is no single
-- bucket to record. The concrete bucket lands on the files row and the document
-- when the upload is written.
CREATE TABLE metaschema_modules_public.file_ref_field (
    id uuid PRIMARY KEY DEFAULT uuidv7(),
    database_id uuid NOT NULL,

    -- The referring table and its upload/image document column.
    table_id uuid NOT NULL,
    field_id uuid NOT NULL,

    -- The buckets/files pair this field's references live in.
    storage_module_id uuid NOT NULL,

    -- Bucket intent, resolved at upload time by function_resolution:
    --   bucket_key   — a logical key, resolved inside the tenant
    --   bucket_tags  — resolve whichever bucket carries these tags
    --   neither      — the reserved default tag for is_public
    -- Never a physical bucket name and never an id: a blueprint names a role,
    -- and buckets stay a tenant-owned concern.
    bucket_key text,
    bucket_tags citext[],

    -- Publicness intent. Selector when no bucket is named (true resolves the
    -- 'default-public' reserved tag, false 'default'); assertion when one is
    -- (resolution raises when the named bucket's type disagrees). Serving
    -- behaviour always comes from the bucket, never from here.
    is_public boolean,

    -- Strict mode: a real FK column beside the document, so Postgres enforces
    -- referential integrity instead of the GC scan. The column is recorded here,
    -- but the generator does not emit the FK yet and refuses a true value rather
    -- than accepting configuration it would silently ignore.
    enforce_fk boolean NOT NULL DEFAULT false,

    CONSTRAINT db_fkey FOREIGN KEY (database_id) REFERENCES metaschema_public.database (id) ON DELETE CASCADE,
    CONSTRAINT table_fkey FOREIGN KEY (table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT field_fkey FOREIGN KEY (field_id) REFERENCES metaschema_public.field (id) ON DELETE CASCADE,
    CONSTRAINT storage_module_fkey FOREIGN KEY (storage_module_id) REFERENCES metaschema_modules_public.storage_module (id) ON DELETE CASCADE,

    -- A key and a tag selector are two answers to one question.
    CONSTRAINT bucket_intent_chk CHECK (bucket_key IS NULL OR bucket_tags IS NULL),

    -- A blank key would resolve to nothing; refuse it at write time.
    CONSTRAINT bucket_key_not_blank_chk CHECK (bucket_key IS NULL OR btrim(bucket_key) <> ''),

    -- One document column projects one file, so one registry row describes it.
    UNIQUE (field_id)
);

CREATE INDEX file_ref_field_database_id_idx ON metaschema_modules_public.file_ref_field ( database_id );
CREATE INDEX file_ref_field_table_id_idx ON metaschema_modules_public.file_ref_field ( table_id );

-- The sync and GC readers both ask "every file-ref field of this module".
CREATE INDEX file_ref_field_storage_module_id_idx ON metaschema_modules_public.file_ref_field ( storage_module_id );

COMMIT;
