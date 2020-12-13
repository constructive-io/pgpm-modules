-- Revert: schemas/collections_public/tables/trigger/policies/enable_row_level_security from pg

BEGIN;


ALTER TABLE collections_public.trigger
    DISABLE ROW LEVEL SECURITY;

COMMIT;  

