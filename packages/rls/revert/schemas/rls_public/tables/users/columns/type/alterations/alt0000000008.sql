-- Revert: schemas/rls_public/tables/users/columns/type/alterations/alt0000000008 from pg

BEGIN;


ALTER TABLE "rls_public".users 
    ALTER COLUMN type DROP DEFAULT;

COMMIT;  

