-- Verify: schemas/collections_public/tables/full_text_search/grants/authenticated/insert on pg

BEGIN;
SELECT verify_table_grant('collections_public.full_text_search', 'insert', 'authenticated');
COMMIT;  

