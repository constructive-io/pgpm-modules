-- Deploy schemas/metaschema_public/tables/policy/table to pg

-- requires: schemas/metaschema_public/schema
-- requires: schemas/metaschema_public/tables/table/table

BEGIN;

CREATE TABLE metaschema_public.policy (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4 (),
  database_id uuid NOT NULL DEFAULT uuid_nil(),

  table_id uuid NOT NULL,
  name text,
  role_name text,
  privilege text,

  -- using_expression text,
  -- check_expression text,
  -- policy_text text,

  permissive boolean default true,
  disabled boolean default false,

  template text,
  data jsonb,

  --

  CONSTRAINT db_fkey FOREIGN KEY (database_id) REFERENCES metaschema_public.database (id) ON DELETE CASCADE,
  CONSTRAINT table_fkey FOREIGN KEY (table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,

  UNIQUE (table_id, name)
);

COMMENT ON CONSTRAINT table_fkey ON metaschema_public.policy IS E'@omit manyToMany';
COMMENT ON CONSTRAINT db_fkey ON metaschema_public.policy IS E'@omit manyToMany';

CREATE INDEX policy_table_id_idx ON metaschema_public.policy ( table_id );
CREATE INDEX policy_database_id_idx ON metaschema_public.policy ( database_id );

COMMIT;
