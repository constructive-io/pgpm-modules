-- Verify: schemas/collections_public/tables/unique_constraint/grants/authenticated/insert on pg

BEGIN;
SELECT verify_table_grant('collections_public.unique_constraint', 'insert', 'authenticated');
COMMIT;  

