-- Deploy schemas/reserved_names/tables/names/table to pg

-- requires: schemas/reserved_names/schema
-- requires: schemas/reserved_names/tables/kinds/table
-- requires: schemas/reserved_names/tables/reasons/table

BEGIN;

CREATE TABLE reserved_names.names (
  kind text NOT NULL REFERENCES reserved_names.kinds (kind),
  name text NOT NULL CHECK (name <> '' AND name = lower(name)),
  match text NOT NULL DEFAULT 'exact' CHECK (match IN ('exact', 'prefix', 'suffix')),
  reason text NOT NULL REFERENCES reserved_names.reasons (reason),
  PRIMARY KEY (kind, name, match)
);

COMMENT ON TABLE reserved_names.names IS 'Names nobody may claim, by kind. Changed only by migrations.';
COMMENT ON COLUMN reserved_names.names.name IS 'The reserved name, lowercase';
COMMENT ON COLUMN reserved_names.names.match IS 'exact: the name itself; prefix: every name starting with it; suffix: every name ending with it';

GRANT SELECT ON TABLE reserved_names.names TO public;

COMMIT;
