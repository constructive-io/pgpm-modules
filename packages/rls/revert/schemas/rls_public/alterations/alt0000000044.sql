-- Revert: schemas/rls_public/alterations/alt0000000044 from pg

BEGIN;
COMMENT ON CONSTRAINT emails_owner_id_fkey ON "rls_public".emails IS NULL;
COMMIT;  

