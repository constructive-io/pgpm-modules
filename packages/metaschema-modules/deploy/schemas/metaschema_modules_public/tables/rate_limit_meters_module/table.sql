-- Deploy schemas/metaschema_modules_public/tables/rate_limit_meters_module/table to pg

-- requires: schemas/metaschema_modules_public/schema

BEGIN;

CREATE TABLE metaschema_modules_public.rate_limit_meters_module (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  database_id uuid NOT NULL,

  -- Public schema: rate_limit_overrides table (admin-manageable via GraphQL API)
  schema_id uuid NOT NULL DEFAULT uuid_nil(),
  -- Private schema: rate_limit_state table, check_rate_limit function (internal)
  private_schema_id uuid NOT NULL DEFAULT uuid_nil(),

  -- Schema name overrides: when set, the trigger uses these instead of hardcoded defaults.
  public_schema_name text,
  private_schema_name text,

  -- State table: sliding window tracking per entity/actor/meter/window (private)
  rate_limit_state_table_id uuid NOT NULL DEFAULT uuid_nil(),
  rate_limit_state_table_name text NOT NULL DEFAULT '',

  -- Overrides table: per-entity and per-actor rate limit overrides (public)
  rate_limit_overrides_table_id uuid NULL,
  rate_limit_overrides_table_name text NOT NULL DEFAULT '',

  -- Rate window limits table: per-plan rate limit configuration (public)
  rate_window_limits_table_id uuid NULL,
  rate_window_limits_table_name text NOT NULL DEFAULT '',

  -- Generated check function (private)
  check_rate_limit_function text NOT NULL DEFAULT '',

  prefix text NULL,

  -- Default capabilities: capability names auto-granted to new members.
  -- NULL uses the module's built-in defaults; explicit array overrides them.
  default_capabilities text[] DEFAULT NULL,

  -- API routing (configurable per-module)
  api_name text DEFAULT 'usage',
  private_api_name text DEFAULT NULL,

  CONSTRAINT db_fkey FOREIGN KEY (database_id) REFERENCES metaschema_public.database (id) ON DELETE CASCADE,
  CONSTRAINT schema_fkey FOREIGN KEY (schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
  CONSTRAINT private_schema_fkey FOREIGN KEY (private_schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
  CONSTRAINT rate_limit_state_table_fkey FOREIGN KEY (rate_limit_state_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
  CONSTRAINT rate_limit_overrides_table_fkey FOREIGN KEY (rate_limit_overrides_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
  CONSTRAINT rate_window_limits_table_fkey FOREIGN KEY (rate_window_limits_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
  CONSTRAINT rate_limit_meters_module_database_id_unique UNIQUE (database_id)
);

COMMENT ON CONSTRAINT rate_limit_state_table_fkey
     ON metaschema_modules_public.rate_limit_meters_module IS E'@fieldName rateLimitStateTableByRateLimitStateTableId';
COMMENT ON CONSTRAINT rate_limit_overrides_table_fkey
     ON metaschema_modules_public.rate_limit_meters_module IS E'@fieldName rateLimitOverridesTableByRateLimitOverridesTableId';
COMMENT ON CONSTRAINT rate_window_limits_table_fkey
     ON metaschema_modules_public.rate_limit_meters_module IS E'@fieldName rateWindowLimitsTableByRateWindowLimitsTableId';

CREATE INDEX rate_limit_meters_module_rate_limit_overrides_table_id_idx ON metaschema_modules_public.rate_limit_meters_module ( rate_limit_overrides_table_id );
CREATE INDEX rate_limit_meters_module_rate_limit_state_table_id_idx ON metaschema_modules_public.rate_limit_meters_module ( rate_limit_state_table_id );
CREATE INDEX rate_limit_meters_module_rate_window_limits_table_id_idx ON metaschema_modules_public.rate_limit_meters_module ( rate_window_limits_table_id );
CREATE INDEX rate_limit_meters_module_private_schema_id_idx ON metaschema_modules_public.rate_limit_meters_module ( private_schema_id );
CREATE INDEX rate_limit_meters_module_schema_id_idx ON metaschema_modules_public.rate_limit_meters_module ( schema_id );

-- Tables this module generates, as opposed to tables it is handed (an
-- entity or users table it points at): the @module_table marker is what
-- metaschema_modules_private.tg_module_install_provenance attributes to this
-- install, keyed by the role name in the column.
COMMENT ON COLUMN metaschema_modules_public.rate_limit_meters_module.rate_limit_overrides_table_id IS '@module_table';
COMMENT ON COLUMN metaschema_modules_public.rate_limit_meters_module.rate_limit_state_table_id IS '@module_table';
COMMENT ON COLUMN metaschema_modules_public.rate_limit_meters_module.rate_window_limits_table_id IS '@module_table';

COMMIT;
