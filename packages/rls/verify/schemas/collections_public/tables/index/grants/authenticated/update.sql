-- Verify: schemas/collections_public/tables/index/grants/authenticated/update on pg

BEGIN;
SELECT verify_table_grant('collections_public.index', 'update', 'authenticated');
COMMIT;  

