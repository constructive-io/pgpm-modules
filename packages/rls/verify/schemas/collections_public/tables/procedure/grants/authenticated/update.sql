-- Verify: schemas/collections_public/tables/procedure/grants/authenticated/update on pg

BEGIN;
SELECT verify_table_grant('collections_public.procedure', 'update', 'authenticated');
COMMIT;  

