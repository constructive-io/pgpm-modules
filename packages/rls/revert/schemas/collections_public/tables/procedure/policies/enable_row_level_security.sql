-- Revert: schemas/collections_public/tables/procedure/policies/enable_row_level_security from pg

BEGIN;


ALTER TABLE collections_public.procedure
    DISABLE ROW LEVEL SECURITY;

COMMIT;  

