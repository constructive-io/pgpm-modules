-- Deploy: schemas/rls_public/alterations/alt0000000044 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema

BEGIN;
COMMENT ON CONSTRAINT emails_owner_id_fkey ON "rls_public".emails IS NULL;
COMMIT;
