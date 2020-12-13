-- Verify: schemas/collections_public/tables/field/grants/authenticated/insert on pg

BEGIN;
SELECT verify_table_grant('collections_public.field', 'insert', 'authenticated');
COMMIT;  

