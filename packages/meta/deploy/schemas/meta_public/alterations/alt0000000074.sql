-- Deploy: schemas/meta_public/alterations/alt0000000074 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema

BEGIN;
COMMENT ON CONSTRAINT organization_settings_address_id_fkey ON "meta_public".organization_settings IS E'@omit manyToMany';
COMMIT;
