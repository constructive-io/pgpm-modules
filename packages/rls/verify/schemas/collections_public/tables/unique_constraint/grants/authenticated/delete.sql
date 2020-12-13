-- Verify: schemas/collections_public/tables/unique_constraint/grants/authenticated/delete on pg

BEGIN;
SELECT verify_table_grant('collections_public.unique_constraint', 'delete', 'authenticated');
COMMIT;  

