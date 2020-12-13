-- Verify: schemas/collections_public/tables/index/grants/authenticated/insert on pg

BEGIN;
SELECT verify_table_grant('collections_public.index', 'insert', 'authenticated');
COMMIT;  

