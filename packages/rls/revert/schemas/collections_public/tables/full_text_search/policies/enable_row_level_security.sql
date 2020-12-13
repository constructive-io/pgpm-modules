-- Revert: schemas/collections_public/tables/full_text_search/policies/enable_row_level_security from pg

BEGIN;


ALTER TABLE collections_public.full_text_search
    DISABLE ROW LEVEL SECURITY;

COMMIT;  

