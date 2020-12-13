-- Verify: schemas/collections_public/tables/full_text_search/grants/authenticated/select on pg

BEGIN;
SELECT verify_table_grant('collections_public.full_text_search', 'select', 'authenticated');
COMMIT;  

