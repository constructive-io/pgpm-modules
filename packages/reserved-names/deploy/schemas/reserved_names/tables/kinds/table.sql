-- Deploy schemas/reserved_names/tables/kinds/table to pg

-- requires: schemas/reserved_names/schema

BEGIN;

CREATE TABLE reserved_names.kinds (
  kind text PRIMARY KEY CHECK (kind ~ '^[a-z][a-z0-9_]*$'),
  description text NOT NULL
);

COMMENT ON TABLE reserved_names.kinds IS 'Categories of names that can be reserved: subdomain, username, domain, slug, ...';

GRANT SELECT ON TABLE reserved_names.kinds TO public;

COMMIT;
