-- Revert: schemas/rls_public/tables/user_contacts/table from pg

BEGIN;
DROP TABLE "rls_public".user_contacts;
COMMIT;  

