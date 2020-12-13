-- Deploy: schemas/rls_public/alterations/alt0000000117 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema

BEGIN;
COMMENT ON CONSTRAINT user_contacts_user_id_fkey ON "rls_public".user_contacts IS NULL;
COMMIT;
