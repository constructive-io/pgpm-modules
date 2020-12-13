-- Revert: schemas/collections_public/tables/schema/policies/enable_row_level_security from pg

BEGIN;


ALTER TABLE collections_public.schema
    DISABLE ROW LEVEL SECURITY;

COMMIT;  

