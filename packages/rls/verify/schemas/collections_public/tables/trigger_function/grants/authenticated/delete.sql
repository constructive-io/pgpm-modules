-- Verify: schemas/collections_public/tables/trigger_function/grants/authenticated/delete on pg

BEGIN;
SELECT verify_table_grant('collections_public.trigger_function', 'delete', 'authenticated');
COMMIT;  

