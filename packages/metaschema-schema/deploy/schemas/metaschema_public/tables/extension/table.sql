-- Deploy schemas/metaschema_public/tables/extension/table to pg

-- requires: schemas/metaschema_public/schema

BEGIN;

-- TODO add package name

CREATE TABLE metaschema_public.extension (
  name text NOT NULL PRIMARY KEY,
  public_schemas text[],
  private_schemas text[]
);

INSERT INTO metaschema_public.extension (name, public_schemas, private_schemas) VALUES 
  (
    'collections',
    ARRAY['metaschema_public'],
    ARRAY['metaschema_private']
  ),
  (
    'meta',
    ARRAY['services_public'],
    ARRAY['services_private']
  )
;

COMMIT;
