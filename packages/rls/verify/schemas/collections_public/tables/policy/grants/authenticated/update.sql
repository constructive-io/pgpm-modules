-- Verify: schemas/collections_public/tables/policy/grants/authenticated/update on pg

BEGIN;
SELECT verify_table_grant('collections_public.policy', 'update', 'authenticated');
COMMIT;  

