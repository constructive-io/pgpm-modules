-- Revert: schemas/rls_public/alterations/alt0000000117 from pg

BEGIN;
COMMENT ON CONSTRAINT user_contacts_user_id_fkey ON "rls_public".user_contacts IS NULL;
COMMIT;  

