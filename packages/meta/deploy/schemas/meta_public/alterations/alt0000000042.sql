-- Deploy: schemas/meta_public/alterations/alt0000000042 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema

BEGIN;
COMMENT ON CONSTRAINT emails_owner_id_fkey ON "meta_public".emails IS NULL;
COMMIT;
