-- Deploy schemas/reserved_names/tables/reasons/table to pg

-- requires: schemas/reserved_names/schema

BEGIN;

CREATE TABLE reserved_names.reasons (
  reason text PRIMARY KEY CHECK (reason ~ '^[a-z][a-z0-9_]*$'),
  description text NOT NULL
);

COMMENT ON TABLE reserved_names.reasons IS 'Why a name is reserved: platform, brand, lookalike, abuse, ...';

GRANT SELECT ON TABLE reserved_names.reasons TO public;

COMMIT;
