-- Revert: schemas/collections_public/tables/policy/policies/enable_row_level_security from pg

BEGIN;


ALTER TABLE collections_public.policy
    DISABLE ROW LEVEL SECURITY;

COMMIT;  

