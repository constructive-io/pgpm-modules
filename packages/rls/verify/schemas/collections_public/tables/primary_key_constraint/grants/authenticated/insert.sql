-- Verify: schemas/collections_public/tables/primary_key_constraint/grants/authenticated/insert on pg

BEGIN;
SELECT verify_table_grant('collections_public.primary_key_constraint', 'insert', 'authenticated');
COMMIT;  

