-- Deploy schemas/metaschema_modules_public/tables/inference_log_module/table to pg

-- requires: schemas/metaschema_modules_public/schema

BEGIN;

CREATE TABLE metaschema_modules_public.inference_log_module (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  database_id uuid NOT NULL,

  schema_id uuid NOT NULL DEFAULT uuid_nil(),
  private_schema_id uuid NOT NULL DEFAULT uuid_nil(),

  -- Inference log table (partitioned by created_at)
  inference_log_table_id uuid NOT NULL DEFAULT uuid_nil(),
  inference_log_table_name text NOT NULL DEFAULT '',

  -- Pre-aggregated daily rollup table
  usage_daily_table_id uuid NOT NULL DEFAULT uuid_nil(),
  usage_daily_table_name text NOT NULL DEFAULT '',

  -- Partition lifecycle configuration
  "interval" text NOT NULL DEFAULT '1 month',
  retention text NULL,
  premake int NOT NULL DEFAULT 2,

  prefix text NULL,

  CONSTRAINT db_fkey FOREIGN KEY (database_id) REFERENCES metaschema_public.database (id) ON DELETE CASCADE,
  CONSTRAINT schema_fkey FOREIGN KEY (schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
  CONSTRAINT private_schema_fkey FOREIGN KEY (private_schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
  CONSTRAINT inference_log_table_fkey FOREIGN KEY (inference_log_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
  CONSTRAINT usage_daily_table_fkey FOREIGN KEY (usage_daily_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
  CONSTRAINT inference_log_module_database_id_unique UNIQUE (database_id)
);

CREATE INDEX inference_log_module_database_id_idx ON metaschema_modules_public.inference_log_module ( database_id );

COMMIT;
