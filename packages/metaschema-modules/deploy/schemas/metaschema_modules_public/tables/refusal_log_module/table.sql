-- Deploy schemas/metaschema_modules_public/tables/refusal_log_module/table to pg

-- requires: schemas/metaschema_modules_public/schema

BEGIN;

-- Platform-only refusal observability: per-minute refusal_log ledger and its
-- daily refusal_usage_summary rollup. Installed once at platform scope; the
-- insert trigger rejects any other scope, so nothing lands in tenant databases.
CREATE TABLE metaschema_modules_public.refusal_log_module (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  database_id uuid NOT NULL,

  -- Scope-key column name on the generated table(s), recorded by the insert
  -- trigger via metaschema_generators.scope_key_column(scope): platform -> NULL.
  entity_field text,
  schema_id uuid NOT NULL DEFAULT uuid_nil(),
  private_schema_id uuid NOT NULL DEFAULT uuid_nil(),

  -- Schema name overrides: when set, the trigger uses these instead of hardcoded defaults.
  public_schema_name text,
  private_schema_name text,

  -- Refusal log (partitioned by minute_bucket — one row per minute/database/lane/reason/route/source)
  log_table_id uuid NOT NULL DEFAULT uuid_nil(),
  log_table_name text NOT NULL DEFAULT '',

  -- Refusal usage summary rollup (partitioned by date)
  summary_table_id uuid NOT NULL DEFAULT uuid_nil(),
  summary_table_name text NOT NULL DEFAULT '',

  -- Generated functions
  record_refusals_function text NOT NULL DEFAULT '',
  rollup_refusal_usage_summary_function text NOT NULL DEFAULT '',

  -- Partition lifecycle configuration: raw tier is short-lived forensics,
  -- summary tier carries the trend.
  log_interval text NOT NULL DEFAULT '1 day',
  log_retention text NOT NULL DEFAULT '7 days',
  log_premake int NOT NULL DEFAULT 2,
  summary_interval text NOT NULL DEFAULT '1 month',
  summary_retention text NOT NULL DEFAULT '3 months',
  summary_premake int NOT NULL DEFAULT 2,

  -- Scope configuration: only 'platform' is accepted.
  scope text NOT NULL,

  -- Table name prefix. Auto-derived from scope by the trigger when empty.
  prefix text NOT NULL DEFAULT '',

  -- API routing (configurable per-module)
  api_name text DEFAULT 'usage',
  private_api_name text DEFAULT NULL,

  CONSTRAINT db_fkey FOREIGN KEY (database_id) REFERENCES metaschema_public.database (id) ON DELETE CASCADE,
  CONSTRAINT schema_fkey FOREIGN KEY (schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
  CONSTRAINT private_schema_fkey FOREIGN KEY (private_schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
  CONSTRAINT log_table_fkey FOREIGN KEY (log_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
  CONSTRAINT summary_table_fkey FOREIGN KEY (summary_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
  CONSTRAINT refusal_log_module_database_id_scope_unique UNIQUE (database_id, scope)
);

CREATE INDEX refusal_log_module_log_table_id_idx ON metaschema_modules_public.refusal_log_module ( log_table_id );
CREATE INDEX refusal_log_module_summary_table_id_idx ON metaschema_modules_public.refusal_log_module ( summary_table_id );
CREATE INDEX refusal_log_module_private_schema_id_idx ON metaschema_modules_public.refusal_log_module ( private_schema_id );
CREATE INDEX refusal_log_module_schema_id_idx ON metaschema_modules_public.refusal_log_module ( schema_id );

-- Tables this module generates: the @module_table marker is what
-- metaschema_modules_private.tg_module_install_provenance attributes to this
-- install, keyed by the role name in the column.
COMMENT ON COLUMN metaschema_modules_public.refusal_log_module.log_table_id IS '@module_table';
COMMENT ON COLUMN metaschema_modules_public.refusal_log_module.summary_table_id IS '@module_table';

COMMIT;
