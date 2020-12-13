-- Verify: schemas/collections_public/tables/trigger_function/grants/authenticated/update on pg

BEGIN;
SELECT verify_table_grant('collections_public.trigger_function', 'update', 'authenticated');
COMMIT;  

