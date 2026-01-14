-- Deploy schemas/metaschema_public/tables/field/table to pg


-- requires: schemas/metaschema_public/schema
-- requires: schemas/metaschema_public/tables/table/table
-- requires: schemas/metaschema_public/types/object_category

BEGIN;

CREATE TABLE metaschema_public.field (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4 (),
  database_id uuid NOT NULL DEFAULT uuid_nil(),
  
  table_id uuid NOT NULL,
  
  name text NOT NULL,
  label text,
  
  description text,
  smart_tags jsonb,

  is_required boolean NOT NULL DEFAULT FALSE,
  default_value text NULL DEFAULT NULL,
  -- AST column for SQL expression validation (AST is the source of truth)
  default_value_ast jsonb NULL DEFAULT NULL,

  -- hidden from API using @omit keyword, a Graphile feature ONLY
  is_hidden boolean NOT NULL DEFAULT FALSE,

  type citext NOT NULL,

  -- typmods DO THIS SOON!

  field_order int not null default 0,

  regexp text default null,
  chk jsonb default null,
  chk_expr jsonb default null,
  min float default null,
  max float default null,

  tags citext[] NOT NULL DEFAULT '{}',

  category metaschema_public.object_category NOT NULL DEFAULT 'app',
  module text NULL,
  scope int NULL,

  --
  CONSTRAINT db_fkey FOREIGN KEY (database_id) REFERENCES metaschema_public.database (id) ON DELETE CASCADE,
  CONSTRAINT table_fkey FOREIGN KEY (table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,

  UNIQUE (table_id, name)
);

COMMENT ON CONSTRAINT table_fkey ON metaschema_public.field IS E'@omit manyToMany';
COMMENT ON CONSTRAINT db_fkey ON metaschema_public.field IS E'@omit manyToMany';

CREATE INDEX field_table_id_idx ON metaschema_public.field ( table_id );
CREATE INDEX field_database_id_idx ON metaschema_public.field ( database_id );

-- Smart comment for Graphile SQL expression validator plugin
COMMENT ON COLUMN metaschema_public.field.default_value IS E'@sqlExpression';

COMMIT;
