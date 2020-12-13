-- Revert: schemas/rls_public/tables/emails/table from pg

BEGIN;
DROP TABLE "rls_public".emails;
COMMIT;  

