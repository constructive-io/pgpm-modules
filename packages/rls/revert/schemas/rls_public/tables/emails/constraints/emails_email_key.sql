-- Revert: schemas/rls_public/tables/emails/constraints/emails_email_key from pg

BEGIN;


ALTER TABLE "rls_public".emails 
    DROP CONSTRAINT emails_email_key;

COMMIT;  

