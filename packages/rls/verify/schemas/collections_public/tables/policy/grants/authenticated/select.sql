-- Verify: schemas/collections_public/tables/policy/grants/authenticated/select on pg

BEGIN;
SELECT verify_table_grant('collections_public.policy', 'select', 'authenticated');
COMMIT;  

