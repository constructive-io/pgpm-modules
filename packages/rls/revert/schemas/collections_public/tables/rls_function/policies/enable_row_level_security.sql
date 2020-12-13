-- Revert: schemas/collections_public/tables/rls_function/policies/enable_row_level_security from pg

BEGIN;


ALTER TABLE collections_public.rls_function
    DISABLE ROW LEVEL SECURITY;

COMMIT;  

