-- Verify: schemas/collections_public/tables/table_grant/grants/authenticated/update on pg

BEGIN;
SELECT verify_table_grant('collections_public.table_grant', 'update', 'authenticated');
COMMIT;  

