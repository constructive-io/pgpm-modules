-- Deploy: schemas/meta_public/alterations/alt0000000136 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema

BEGIN;
COMMENT ON CONSTRAINT site_metadata_site_id_fkey ON "meta_public".site_metadata IS E'@omit manyToMany';
COMMIT;
