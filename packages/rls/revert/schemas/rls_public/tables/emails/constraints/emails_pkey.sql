-- Revert: schemas/rls_public/tables/emails/constraints/emails_pkey from pg

BEGIN;


ALTER TABLE "rls_public".emails 
    DROP CONSTRAINT emails_pkey;

COMMIT;  

