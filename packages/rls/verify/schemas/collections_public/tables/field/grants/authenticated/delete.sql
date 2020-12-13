-- Verify: schemas/collections_public/tables/field/grants/authenticated/delete on pg

BEGIN;
SELECT verify_table_grant('collections_public.field', 'delete', 'authenticated');
COMMIT;  

