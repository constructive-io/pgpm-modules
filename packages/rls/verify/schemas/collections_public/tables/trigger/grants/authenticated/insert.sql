-- Verify: schemas/collections_public/tables/trigger/grants/authenticated/insert on pg

BEGIN;
SELECT verify_table_grant('collections_public.trigger', 'insert', 'authenticated');
COMMIT;  

