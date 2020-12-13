-- Verify: schemas/collections_public/tables/trigger/grants/authenticated/update on pg

BEGIN;
SELECT verify_table_grant('collections_public.trigger', 'update', 'authenticated');
COMMIT;  

