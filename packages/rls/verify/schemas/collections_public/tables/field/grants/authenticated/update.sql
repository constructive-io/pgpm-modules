-- Verify: schemas/collections_public/tables/field/grants/authenticated/update on pg

BEGIN;
SELECT verify_table_grant('collections_public.field', 'update', 'authenticated');
COMMIT;  

