-- Verify: schemas/collections_public/tables/table_grant/grants/authenticated/insert on pg

BEGIN;
SELECT verify_table_grant('collections_public.table_grant', 'insert', 'authenticated');
COMMIT;  

