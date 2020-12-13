-- Verify: schemas/collections_public/tables/field/grants/authenticated/select on pg

BEGIN;
SELECT verify_table_grant('collections_public.field', 'select', 'authenticated');
COMMIT;  

