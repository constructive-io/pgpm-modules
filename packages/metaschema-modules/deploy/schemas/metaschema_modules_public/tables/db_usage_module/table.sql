-- Deploy schemas/metaschema_modules_public/tables/db_usage_module/table to pg

-- requires: schemas/metaschema_modules_public/schema

BEGIN;

CREATE TABLE metaschema_modules_public.db_usage_module (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  database_id uuid NOT NULL,

  schema_id uuid NOT NULL DEFAULT uuid_nil(),
  private_schema_id uuid NOT NULL DEFAULT uuid_nil(),

  -- DB table stats log (partitioned — per-table reads/writes/size from pg_stat_user_tables)
  table_stats_log_table_id uuid NOT NULL DEFAULT uuid_nil(),
  table_stats_log_table_name text NOT NULL DEFAULT '',

  -- DB table stats daily rollup
  table_stats_daily_table_id uuid NOT NULL DEFAULT uuid_nil(),
  table_stats_daily_table_name text NOT NULL DEFAULT '',

  -- DB query stats log (partitioned — query execution time from pg_stat_statements)
  query_stats_log_table_id uuid NOT NULL DEFAULT uuid_nil(),
  query_stats_log_table_name text NOT NULL DEFAULT '',

  -- DB query stats daily rollup
  query_stats_daily_table_id uuid NOT NULL DEFAULT uuid_nil(),
  query_stats_daily_table_name text NOT NULL DEFAULT '',

  -- Partition lifecycle configuration
  "interval" text NOT NULL DEFAULT '1 month',
  retention text NOT NULL DEFAULT '12 months',
  premake int NOT NULL DEFAULT 2,

  -- Scope configuration: 'app' = per-app usage, 'platform' = tenant metering (database_id RLS)
  scope text NOT NULL DEFAULT 'app',

  prefix text NULL,

  CONSTRAINT db_fkey FOREIGN KEY (database_id) REFERENCES metaschema_public.database (id) ON DELETE CASCADE,
  CONSTRAINT schema_fkey FOREIGN KEY (schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
  CONSTRAINT private_schema_fkey FOREIGN KEY (private_schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
  CONSTRAINT table_stats_log_table_fkey FOREIGN KEY (table_stats_log_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
  CONSTRAINT table_stats_daily_table_fkey FOREIGN KEY (table_stats_daily_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
  CONSTRAINT query_stats_log_table_fkey FOREIGN KEY (query_stats_log_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
  CONSTRAINT query_stats_daily_table_fkey FOREIGN KEY (query_stats_daily_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
  CONSTRAINT db_usage_module_database_id_prefix_unique UNIQUE NULLS NOT DISTINCT (database_id, prefix)
);

CREATE INDEX db_usage_module_database_id_idx ON metaschema_modules_public.db_usage_module ( database_id );

COMMIT;
