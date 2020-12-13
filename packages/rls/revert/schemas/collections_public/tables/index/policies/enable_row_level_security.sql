-- Revert: schemas/collections_public/tables/index/policies/enable_row_level_security from pg

BEGIN;


ALTER TABLE collections_public.index
    DISABLE ROW LEVEL SECURITY;

COMMIT;  

