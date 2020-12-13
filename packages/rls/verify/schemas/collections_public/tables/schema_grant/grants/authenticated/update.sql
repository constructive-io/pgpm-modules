-- Verify: schemas/collections_public/tables/schema_grant/grants/authenticated/update on pg

BEGIN;
SELECT verify_table_grant('collections_public.schema_grant', 'update', 'authenticated');
COMMIT;  

