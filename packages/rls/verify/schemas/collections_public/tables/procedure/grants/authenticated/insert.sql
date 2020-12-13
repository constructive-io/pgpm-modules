-- Verify: schemas/collections_public/tables/procedure/grants/authenticated/insert on pg

BEGIN;
SELECT verify_table_grant('collections_public.procedure', 'insert', 'authenticated');
COMMIT;  

