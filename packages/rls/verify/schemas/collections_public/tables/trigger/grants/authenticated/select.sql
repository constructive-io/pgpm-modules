-- Verify: schemas/collections_public/tables/trigger/grants/authenticated/select on pg

BEGIN;
SELECT verify_table_grant('collections_public.trigger', 'select', 'authenticated');
COMMIT;  

