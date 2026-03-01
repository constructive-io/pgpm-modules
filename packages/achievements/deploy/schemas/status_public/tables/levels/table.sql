-- Deploy schemas/status_public/tables/levels/table to pg

-- requires: schemas/status_public/schema

BEGIN;

CREATE TABLE status_public.levels (
  name text NOT NULL PRIMARY KEY
);

COMMENT ON TABLE status_public.levels IS 'Levels for achievement';
COMMENT ON COLUMN status_public.levels.name IS 'Unique level name used as the primary key (e.g. bronze, silver, gold)';

GRANT SELECT ON TABLE status_public.levels TO public;

COMMIT;
