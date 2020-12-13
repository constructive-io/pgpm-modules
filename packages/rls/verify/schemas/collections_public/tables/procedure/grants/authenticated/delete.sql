-- Verify: schemas/collections_public/tables/procedure/grants/authenticated/delete on pg

BEGIN;
SELECT verify_table_grant('collections_public.procedure', 'delete', 'authenticated');
COMMIT;  

