-- Revert: schemas/rls_public/alterations/alt0000000114 from pg

BEGIN;
COMMENT ON COLUMN "rls_public".user_contacts.full_name IS NULL;
COMMIT;  

