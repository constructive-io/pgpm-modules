-- Deploy schemas/metaschema_public/tables/rls_function/table to pg

-- requires: schemas/metaschema_public/schema
-- requires: schemas/metaschema_public/tables/database/table

BEGIN;

CREATE TABLE metaschema_public.rls_function (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4 (),
  database_id uuid NOT NULL DEFAULT uuid_nil(),

  table_id uuid NOT NULL,

  name text,
  label text,
  description text,

  data jsonb,

  inline boolean default false,
  security int default 0, -- 0 = invoker, 1 = definer (only when inline is false can we apply this)

  --

  CONSTRAINT db_fkey FOREIGN KEY (database_id) REFERENCES metaschema_public.database (id) ON DELETE CASCADE,
  CONSTRAINT table_fkey FOREIGN KEY (table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,

  UNIQUE (database_id, name)
);

COMMENT ON CONSTRAINT db_fkey ON metaschema_public.rls_function IS E'@omit manyToMany';
COMMENT ON CONSTRAINT table_fkey ON metaschema_public.rls_function IS E'@omit manyToMany';
CREATE INDEX rls_function_table_id_idx ON metaschema_public.rls_function ( table_id );
CREATE INDEX rls_function_database_id_idx ON metaschema_public.rls_function ( database_id );

COMMIT;
