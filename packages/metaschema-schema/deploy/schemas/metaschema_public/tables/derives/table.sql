-- Deploy schemas/metaschema_public/tables/derives/table to pg

-- requires: schemas/metaschema_public/schema
-- requires: schemas/metaschema_public/tables/database/table
-- requires: schemas/metaschema_public/tables/table/table

BEGIN;

-- Records that a companion table derives from a source table (e.g. a
-- `_history` or `_i18n` table). One row per (derived table, source table)
-- pair. Policy derivation reads this to know which companions to keep in
-- sync when the source table's policy set changes.
CREATE TABLE metaschema_public.derives (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  database_id uuid NOT NULL DEFAULT uuid_nil(),

  -- the derived companion table
  table_id uuid NOT NULL,

  -- the table it derives from
  source_table_id uuid NOT NULL,

  -- what kind of derivation produced the companion ('history', 'i18n', ...)
  kind text NOT NULL,

  -- policy derivation configuration
  include_mutations boolean NOT NULL DEFAULT false,
  policy_prefix text NOT NULL DEFAULT 'derived',

  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),

  CONSTRAINT db_fkey FOREIGN KEY (database_id) REFERENCES metaschema_public.database (id) ON DELETE CASCADE,
  CONSTRAINT table_fkey FOREIGN KEY (table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
  CONSTRAINT source_table_fkey FOREIGN KEY (source_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,

  CONSTRAINT valid_kind CHECK (length(kind) > 0),
  CONSTRAINT no_self_derivation CHECK (table_id <> source_table_id),

  CONSTRAINT derives_table_source_uniq UNIQUE (table_id, source_table_id)
);

CREATE INDEX derives_table_id_idx ON metaschema_public.derives ( table_id );
CREATE INDEX derives_source_table_id_idx ON metaschema_public.derives ( source_table_id );
CREATE INDEX derives_database_id_idx ON metaschema_public.derives ( database_id );

COMMIT;
