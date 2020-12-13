-- Revert: schemas/rls_public/tables/user_contacts/constraints/user_contacts_pkey from pg

BEGIN;


ALTER TABLE "rls_public".user_contacts 
    DROP CONSTRAINT user_contacts_pkey;

COMMIT;  

