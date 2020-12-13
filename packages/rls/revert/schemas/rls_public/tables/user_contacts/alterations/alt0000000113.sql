-- Revert: schemas/rls_public/tables/user_contacts/alterations/alt0000000113 from pg

BEGIN;
ALTER TABLE "rls_public".user_contacts DROP CONSTRAINT user_contacts_full_name_chk;
COMMIT;  

