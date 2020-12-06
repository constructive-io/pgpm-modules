-- Deploy: schemas/meta_public/alterations/alt0000000116 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema

BEGIN;
COMMENT ON CONSTRAINT api_modules_api_id_fkey ON "meta_public".api_modules IS E'@omit manyToMany';
COMMIT;
