-- Deploy schemas/metaschema_public/tables/domain_type/table to pg

-- requires: schemas/metaschema_public/schema
-- requires: schemas/metaschema_public/tables/database/table
-- requires: schemas/metaschema_public/tables/schema/table
-- requires: schemas/metaschema_public/types/object_category

BEGIN;

CREATE TABLE metaschema_public.domain_type (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  database_id uuid NOT NULL,
  schema_id uuid NOT NULL,
  name text NOT NULL,

  label text,
  description text,

  -- Base type reference, same FieldType JSONB shape as field.type ({ name, schema?, args?, array_dimensions? }).
  base_type jsonb NOT NULL,

  not_null boolean NOT NULL DEFAULT false,

  -- Raw, sanitized expression ASTs. check_expr references the domain VALUE keyword
  -- (a bare "value" ColumnRef) and is validated at the 'column' level; default_expr
  -- is validated at the 'expression' level, matching field.default_value.
  check_expr jsonb,
  default_expr jsonb,

  smart_tags jsonb,

  category metaschema_public.object_category NOT NULL DEFAULT 'app',

  tags citext[] NOT NULL DEFAULT '{}',

  CONSTRAINT db_fkey FOREIGN KEY (database_id) REFERENCES metaschema_public.database (id) ON DELETE CASCADE,
  CONSTRAINT schema_fkey FOREIGN KEY (schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,

  UNIQUE (schema_id, name)
);


CREATE INDEX domain_type_database_id_idx ON metaschema_public.domain_type ( database_id );

COMMIT;
