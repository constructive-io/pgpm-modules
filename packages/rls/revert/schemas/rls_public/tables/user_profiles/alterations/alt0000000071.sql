-- Revert: schemas/rls_public/tables/user_profiles/alterations/alt0000000071 from pg

BEGIN;


ALTER TABLE "rls_public".user_profiles
    ENABLE ROW LEVEL SECURITY;

COMMIT;  

