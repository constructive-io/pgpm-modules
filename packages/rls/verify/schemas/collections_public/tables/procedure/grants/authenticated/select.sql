-- Verify: schemas/collections_public/tables/procedure/grants/authenticated/select on pg

BEGIN;
SELECT verify_table_grant('collections_public.procedure', 'select', 'authenticated');
COMMIT;  

