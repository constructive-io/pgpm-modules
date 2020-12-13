-- Revert: schemas/rls_public/tables/user_characteristics/constraints/user_characteristics_user_id_fkey from pg

BEGIN;


ALTER TABLE "rls_public".user_characteristics 
    DROP CONSTRAINT user_characteristics_user_id_fkey;

COMMIT;  

