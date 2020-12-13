-- Verify: schemas/collections_public/tables/rls_function/grants/authenticated/update on pg

BEGIN;
SELECT verify_table_grant('collections_public.rls_function', 'update', 'authenticated');
COMMIT;  

