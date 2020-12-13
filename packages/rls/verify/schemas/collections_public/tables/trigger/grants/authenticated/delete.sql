-- Verify: schemas/collections_public/tables/trigger/grants/authenticated/delete on pg

BEGIN;
SELECT verify_table_grant('collections_public.trigger', 'delete', 'authenticated');
COMMIT;  

