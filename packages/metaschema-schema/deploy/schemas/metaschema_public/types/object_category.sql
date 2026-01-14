-- Deploy schemas/metaschema_public/types/object_category to pg

-- requires: schemas/metaschema_public/schema

BEGIN;

CREATE TYPE metaschema_public.object_category AS ENUM ('core', 'module', 'app');

COMMIT;
