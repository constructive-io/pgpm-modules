-- Deploy: schemas/meta_public/alterations/alt0000000123 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema

BEGIN;
COMMENT ON CONSTRAINT site_modules_site_id_fkey ON "meta_public".site_modules IS E'@omit manyToMany';
COMMIT;
