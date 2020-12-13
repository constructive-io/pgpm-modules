-- Revert: schemas/rls_public/tables/users/table from pg

BEGIN;
DROP TABLE "rls_public".users;
COMMIT;  

