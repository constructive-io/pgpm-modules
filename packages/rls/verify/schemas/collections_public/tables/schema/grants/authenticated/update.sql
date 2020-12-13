-- Verify: schemas/collections_public/tables/schema/grants/authenticated/update on pg

BEGIN;
SELECT verify_table_grant('collections_public.schema', 'update', 'authenticated');
COMMIT;  

