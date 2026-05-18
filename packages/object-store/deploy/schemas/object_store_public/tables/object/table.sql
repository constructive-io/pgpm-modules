-- Deploy schemas/object_store_public/tables/object/table to pg

-- requires: schemas/object_store_public/schema

BEGIN;

CREATE TABLE object_store_public.object (
  id uuid NOT NULL,
  scope_id uuid NOT NULL,
  kids uuid[],
  ktree text[],
  data jsonb,
  frzn bool default false,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id, scope_id),
  CONSTRAINT kids_ktree_length_match CHECK (
    cardinality(kids) = cardinality(ktree)
    OR (kids IS NULL AND ktree IS NULL)
  )
);

COMMIT;
