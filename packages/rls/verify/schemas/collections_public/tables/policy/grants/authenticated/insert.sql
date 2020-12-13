-- Verify: schemas/collections_public/tables/policy/grants/authenticated/insert on pg

BEGIN;
SELECT verify_table_grant('collections_public.policy', 'insert', 'authenticated');
COMMIT;  

