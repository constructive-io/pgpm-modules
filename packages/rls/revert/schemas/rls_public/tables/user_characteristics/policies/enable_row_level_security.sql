-- Revert: schemas/rls_public/tables/user_characteristics/policies/enable_row_level_security from pg

BEGIN;


ALTER TABLE "rls_public".user_characteristics
    DISABLE ROW LEVEL SECURITY;

COMMIT;  

