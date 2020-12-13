-- Revert: schemas/rls_public/tables/user_contacts/columns/user_id/alterations/alt0000000116 from pg

BEGIN;


ALTER TABLE "rls_public".user_contacts 
    ALTER COLUMN user_id DROP NOT NULL;


COMMIT;  

