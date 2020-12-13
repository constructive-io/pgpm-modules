-- Verify: schemas/collections_public/tables/schema/grants/authenticated/delete on pg

BEGIN;
SELECT verify_table_grant('collections_public.schema', 'delete', 'authenticated');
COMMIT;  

