-- Verify: schemas/collections_public/tables/schema/grants/authenticated/insert on pg

BEGIN;
SELECT verify_table_grant('collections_public.schema', 'insert', 'authenticated');
COMMIT;  

