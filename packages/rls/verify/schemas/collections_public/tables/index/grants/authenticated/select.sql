-- Verify: schemas/collections_public/tables/index/grants/authenticated/select on pg

BEGIN;
SELECT verify_table_grant('collections_public.index', 'select', 'authenticated');
COMMIT;  

