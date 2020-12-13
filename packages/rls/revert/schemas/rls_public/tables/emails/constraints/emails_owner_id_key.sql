-- Revert: schemas/rls_public/tables/emails/constraints/emails_owner_id_key from pg

BEGIN;


ALTER TABLE "rls_public".emails 
    DROP CONSTRAINT emails_owner_id_key;

COMMIT;  

