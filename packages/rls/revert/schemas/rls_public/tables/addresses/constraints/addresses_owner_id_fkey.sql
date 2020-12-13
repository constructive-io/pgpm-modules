-- Revert: schemas/rls_public/tables/addresses/constraints/addresses_owner_id_fkey from pg

BEGIN;


ALTER TABLE "rls_public".addresses 
    DROP CONSTRAINT addresses_owner_id_fkey;

COMMIT;  

