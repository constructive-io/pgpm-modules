-- Deploy schemas/collections_public/tables/rls_function/table to pg

-- requires: schemas/collections_public/schema
-- requires: schemas/collections_public/tables/database/table

BEGIN;

CREATE TABLE collections_public.rls_function (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4 (),
  database_id uuid NOT NULL,
  name text NOT NULL,

  function_template_name text,
  function_template_vars json,
  label text,
  description text,
  --

  CONSTRAINT db_fkey FOREIGN KEY (database_id) REFERENCES collections_public.database (id) ON DELETE CASCADE,

  UNIQUE(function_template_name, database_id),
  UNIQUE (database_id, name)
);

COMMENT ON CONSTRAINT db_fkey ON collections_public.rls_function IS E'@omit manyToMany';
CREATE INDEX rls_function_database_id_idx ON collections_public.rls_function ( database_id );

COMMIT;
