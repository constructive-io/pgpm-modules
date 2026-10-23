-- Deploy schemas/reserved_names/tables/names/table to pg

-- requires: schemas/reserved_names/schema

BEGIN;

CREATE TABLE reserved_names.names (
  kind text NOT NULL CHECK (kind ~ '^[a-z][a-z0-9_]*$'),
  name text NOT NULL CHECK (name <> '' AND name = lower(name)),
  is_prefix boolean NOT NULL DEFAULT false,
  reason text,
  PRIMARY KEY (kind, name)
);

COMMENT ON TABLE reserved_names.names IS 'Names nobody may claim, grouped by kind (subdomain, username, slug, ...). Changed only by migrations.';
COMMENT ON COLUMN reserved_names.names.kind IS 'What kind of name this reserves, e.g. subdomain or username';
COMMENT ON COLUMN reserved_names.names.name IS 'The reserved name, lowercase';
COMMENT ON COLUMN reserved_names.names.is_prefix IS 'When true, every name starting with this one is reserved too';
COMMENT ON COLUMN reserved_names.names.reason IS 'Why the name is reserved';

GRANT SELECT ON TABLE reserved_names.names TO public;

COMMIT;
