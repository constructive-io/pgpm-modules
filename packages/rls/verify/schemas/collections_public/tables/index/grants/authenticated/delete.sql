-- Verify: schemas/collections_public/tables/index/grants/authenticated/delete on pg

BEGIN;
SELECT verify_table_grant('collections_public.index', 'delete', 'authenticated');
COMMIT;  

