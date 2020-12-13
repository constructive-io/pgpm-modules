-- Revert: schemas/rls_public/tables/user_profiles/columns/id/alterations/alt0000000072 from pg

BEGIN;


ALTER TABLE "rls_public".user_profiles 
    ALTER COLUMN id DROP NOT NULL;


COMMIT;  

