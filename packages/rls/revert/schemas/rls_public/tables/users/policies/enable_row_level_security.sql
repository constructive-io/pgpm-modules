-- Revert: schemas/rls_public/tables/users/policies/enable_row_level_security from pg

BEGIN;


ALTER TABLE "rls_public".users
    DISABLE ROW LEVEL SECURITY;

COMMIT;  

