-- Deploy schemas/metaschema_public/tables/table/table to pg
-- requires: schemas/metaschema_public/schema
-- requires: schemas/metaschema_public/tables/database/table
-- requires: schemas/metaschema_public/tables/schema/table
-- requires: schemas/metaschema_public/types/object_category
-- requires: schemas/metaschema_private/procedures/is_valid_step_up

BEGIN;

CREATE TABLE metaschema_public.table (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  database_id uuid NOT NULL DEFAULT uuid_nil(),

  schema_id uuid NOT NULL,
  
  name text NOT NULL,

  label text,
  description text,
  
  smart_tags jsonb,
  
  category metaschema_public.object_category NOT NULL DEFAULT 'app',

  use_rls boolean NOT NULL DEFAULT FALSE,
  
  timestamps boolean NOT NULL DEFAULT FALSE,
  peoplestamps boolean NOT NULL DEFAULT FALSE,
  principalstamps boolean NOT NULL DEFAULT FALSE,

  plural_name text,
  singular_name text,

  tags citext[] NOT NULL DEFAULT '{}',

  step_up jsonb DEFAULT NULL,

  partitioned boolean NOT NULL DEFAULT false,
  partition_strategy text DEFAULT NULL,
  partition_key_names text[] DEFAULT NULL,
  partition_key_types text[] DEFAULT NULL,

  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),

  CONSTRAINT db_fkey FOREIGN KEY (database_id) REFERENCES metaschema_public.database (id) ON DELETE CASCADE,
  CONSTRAINT schema_fkey FOREIGN KEY (schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
  
  UNIQUE (database_id, schema_id, name),

  CONSTRAINT table_step_up_check CHECK (
    step_up IS NULL OR metaschema_private.is_valid_step_up(step_up)
  )
);

COMMENT ON COLUMN metaschema_public.table.step_up IS
  'Declarative step-up auth guard: jsonb object mapping DML verbs (INSERT, UPDATE, DELETE) to a step-up spec. Values: true (default fresh_auth), a type string (password / mfa / fresh_auth; password_or_mfa is the legacy spelling), or an object {type, min_age, min_age_lookup, conditions} where min_age is an interval string (e.g. 6 hours) gating the guard to rows older than that age (UPDATE/DELETE only), min_age_lookup resolves per-row windows from a lookup table, and conditions is a declarative WHEN-clause tree compiled by build_condition_expr.';

ALTER TABLE metaschema_public.table ADD COLUMN
    inherits_id uuid NULL REFERENCES metaschema_public.table(id);

-- Provenance for a table a module generated: which module installed it, which
-- instance of that module, and the module's own name for the table's role
-- ('message', 'thread', ...). A module chooses its tables' names, prefixes them
-- per install and may move them between schemas, so a consumer that wants "this
-- module instance's message table" cannot name it — it selects on the
-- provenance instead. NULL on every table no module generated.
ALTER TABLE metaschema_public.table
    ADD COLUMN module_type text NULL,
    ADD COLUMN module_id uuid NULL,
    ADD COLUMN module_scope text NULL,
    ADD COLUMN module_prefix text NULL,
    ADD COLUMN module_table_key text NULL;

-- One table per (module instance, role): scope and prefix are the
-- discriminators an instance is installed under, so they participate.
-- COALESCE because a module without scopes leaves both NULL, and NULLs would
-- otherwise compare distinct and let a role be claimed twice.
CREATE UNIQUE INDEX table_module_provenance_uniq
    ON metaschema_public.table (
        database_id,
        module_type,
        COALESCE(module_scope, ''),
        COALESCE(module_prefix, ''),
        module_table_key
    )
    WHERE module_type IS NOT NULL AND module_table_key IS NOT NULL;

-- Generator-written machinery, kept off the API the way schema_hash is: a client
-- that could write these could point a blueprint reference at a table the module
-- never generated, and reading them is a platform concern, not an app one.
COMMENT ON COLUMN metaschema_public.table.module_type IS '@behavior -*';
COMMENT ON COLUMN metaschema_public.table.module_id IS '@behavior -*';
COMMENT ON COLUMN metaschema_public.table.module_scope IS '@behavior -*';
COMMENT ON COLUMN metaschema_public.table.module_prefix IS '@behavior -*';
COMMENT ON COLUMN metaschema_public.table.module_table_key IS '@behavior -*';


CREATE INDEX table_schema_id_idx ON metaschema_public.table ( schema_id );
CREATE INDEX table_inherits_id_idx ON metaschema_public.table ( inherits_id );

COMMIT;

