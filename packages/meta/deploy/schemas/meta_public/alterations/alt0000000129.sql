-- Deploy: schemas/meta_public/alterations/alt0000000129 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema

BEGIN;
COMMENT ON CONSTRAINT site_themes_site_id_fkey ON "meta_public".site_themes IS E'@omit manyToMany';
COMMIT;
