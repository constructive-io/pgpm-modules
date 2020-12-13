-- Verify: schemas/collections_public/tables/schema/grants/authenticated/select on pg

BEGIN;
SELECT verify_table_grant('collections_public.schema', 'select', 'authenticated');
COMMIT;  

