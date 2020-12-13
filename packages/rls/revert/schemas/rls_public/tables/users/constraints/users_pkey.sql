-- Revert: schemas/rls_public/tables/users/constraints/users_pkey from pg

BEGIN;


ALTER TABLE "rls_public".users 
    DROP CONSTRAINT users_pkey;

COMMIT;  

