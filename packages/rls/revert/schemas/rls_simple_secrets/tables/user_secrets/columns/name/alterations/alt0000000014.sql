-- Revert: schemas/rls_simple_secrets/tables/user_secrets/columns/name/alterations/alt0000000014 from pg

BEGIN;


ALTER TABLE "rls_simple_secrets".user_secrets 
    ALTER COLUMN name DROP NOT NULL;


COMMIT;  

