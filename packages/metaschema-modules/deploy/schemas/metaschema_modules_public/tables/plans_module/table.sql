-- Deploy schemas/metaschema_modules_public/tables/plans_module/table to pg

-- requires: schemas/metaschema_modules_public/schema

BEGIN;

CREATE TABLE metaschema_modules_public.plans_module (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  database_id uuid NOT NULL,

  schema_id uuid NOT NULL DEFAULT uuid_nil(),
  private_schema_id uuid NOT NULL DEFAULT uuid_nil(),

  -- Plans table: defines plan tiers (Free, Pro, Enterprise)
  plans_table_id uuid NOT NULL DEFAULT uuid_nil(),
  plans_table_name text NOT NULL DEFAULT '',

  -- Plan limits table: maps plan → limit name → max value
  plan_limits_table_id uuid NOT NULL DEFAULT uuid_nil(),
  plan_limits_table_name text NOT NULL DEFAULT '',

  -- Plan pricing table: billing cycles, prices, discounts per plan
  plan_pricing_table_id uuid NULL,

  -- Plan overrides table: per-entity custom limit overrides
  plan_overrides_table_id uuid NULL,

  -- Generated apply_plan functions (one per limits scope)
  apply_plan_function text NOT NULL DEFAULT '',
  apply_plan_aggregate_function text NOT NULL DEFAULT '',

  prefix text NULL,

  CONSTRAINT db_fkey FOREIGN KEY (database_id) REFERENCES metaschema_public.database (id) ON DELETE CASCADE,
  CONSTRAINT schema_fkey FOREIGN KEY (schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
  CONSTRAINT private_schema_fkey FOREIGN KEY (private_schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
  CONSTRAINT plans_table_fkey FOREIGN KEY (plans_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
  CONSTRAINT plan_limits_table_fkey FOREIGN KEY (plan_limits_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
  CONSTRAINT plan_pricing_table_fkey FOREIGN KEY (plan_pricing_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
  CONSTRAINT plan_overrides_table_fkey FOREIGN KEY (plan_overrides_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
  CONSTRAINT plans_module_database_id_unique UNIQUE (database_id)
);

CREATE INDEX plans_module_database_id_idx ON metaschema_modules_public.plans_module ( database_id );

COMMIT;
