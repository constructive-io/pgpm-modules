-- Revert: schemas/rls_public/tables/user_profiles/table from pg

BEGIN;
DROP TABLE "rls_public".user_profiles;
COMMIT;  

