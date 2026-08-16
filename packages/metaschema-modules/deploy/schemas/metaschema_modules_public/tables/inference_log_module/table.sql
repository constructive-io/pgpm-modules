-- Deploy schemas/metaschema_modules_public/tables/inference_log_module/table to pg

-- requires: schemas/metaschema_modules_public/schema

BEGIN;

CREATE TABLE metaschema_modules_public.inference_log_module (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  database_id uuid NOT NULL,


  -- Scope-key column name on the generated table(s), recorded by the insert
  -- trigger via metaschema_generators.scope_key_column(scope, key): database ->
  -- 'database_id', entity -> the module's key ('entity_id' here), global -> NULL.
  entity_field text,
  schema_id uuid NOT NULL DEFAULT uuid_nil(),
  private_schema_id uuid NOT NULL DEFAULT uuid_nil(),

  -- Schema name overrides: when set, the trigger uses these instead of hardcoded defaults.
  public_schema_name text,
  private_schema_name text,

  -- Inference log table (partitioned by created_at)
  inference_log_table_id uuid NOT NULL DEFAULT uuid_nil(),
  inference_log_table_name text NOT NULL DEFAULT '',

  -- Pre-aggregated usage summary rollup table
  usage_summary_table_id uuid NOT NULL DEFAULT uuid_nil(),
  usage_summary_table_name text NOT NULL DEFAULT '',

  -- Partition lifecycle configuration
  "interval" text NOT NULL DEFAULT '1 month',
  retention text NOT NULL DEFAULT '12 months',
  premake int NOT NULL DEFAULT 2,

  -- Scope the log plane is installed at. Rows are read through
  -- entity membership on entity_id at every scope, plus the actor's own rows
  -- outside the constructive scopes.
  scope text NOT NULL,

  -- Table name prefix. Auto-derived from scope by the trigger when empty.
  prefix text NOT NULL DEFAULT '',

  -- Name of the AST-generated rollup function in the private schema. It
  -- carries the same prefix as the tables, so two scopes of this module
  -- share one private schema without colliding, and a reader (the worker's
  -- rollup pass) calls the function belonging to the instance it loaded.
  rollup_function_name text NOT NULL DEFAULT '',

  -- API routing (configurable per-module)
  api_name text DEFAULT 'usage',
  private_api_name text DEFAULT NULL,

  CONSTRAINT db_fkey FOREIGN KEY (database_id) REFERENCES metaschema_public.database (id) ON DELETE CASCADE,
  CONSTRAINT schema_fkey FOREIGN KEY (schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
  CONSTRAINT private_schema_fkey FOREIGN KEY (private_schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
  CONSTRAINT inference_log_table_fkey FOREIGN KEY (inference_log_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
  CONSTRAINT usage_summary_table_fkey FOREIGN KEY (usage_summary_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
  CONSTRAINT inference_log_module_database_id_prefix_unique UNIQUE NULLS NOT DISTINCT (database_id, prefix)
);

CREATE INDEX inference_log_module_inference_log_table_id_idx ON metaschema_modules_public.inference_log_module ( inference_log_table_id );
CREATE INDEX inference_log_module_usage_summary_table_id_idx ON metaschema_modules_public.inference_log_module ( usage_summary_table_id );
CREATE INDEX inference_log_module_private_schema_id_idx ON metaschema_modules_public.inference_log_module ( private_schema_id );
CREATE INDEX inference_log_module_schema_id_idx ON metaschema_modules_public.inference_log_module ( schema_id );

-- Tables this module generates, as opposed to tables it is handed (an
-- entity or users table it points at): the @module_table marker is what
-- metaschema_modules_private.tg_module_install_provenance attributes to this
-- install, keyed by the role name in the column.
COMMENT ON COLUMN metaschema_modules_public.inference_log_module.inference_log_table_id IS '@module_table';
COMMENT ON COLUMN metaschema_modules_public.inference_log_module.usage_summary_table_id IS '@module_table';

COMMIT;
