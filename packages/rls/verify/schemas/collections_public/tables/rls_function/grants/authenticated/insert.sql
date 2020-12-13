-- Verify: schemas/collections_public/tables/rls_function/grants/authenticated/insert on pg

BEGIN;
SELECT verify_table_grant('collections_public.rls_function', 'insert', 'authenticated');
COMMIT;  

