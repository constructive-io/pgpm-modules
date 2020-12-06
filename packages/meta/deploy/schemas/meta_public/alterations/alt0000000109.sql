-- Deploy: schemas/meta_public/alterations/alt0000000109 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema

BEGIN;
COMMENT ON CONSTRAINT sites_owner_id_fkey ON "meta_public".sites IS E'@omit manyToMany';
COMMIT;
