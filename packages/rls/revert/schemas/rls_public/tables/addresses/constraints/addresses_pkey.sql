-- Revert: schemas/rls_public/tables/addresses/constraints/addresses_pkey from pg

BEGIN;


ALTER TABLE "rls_public".addresses 
    DROP CONSTRAINT addresses_pkey;

COMMIT;  

