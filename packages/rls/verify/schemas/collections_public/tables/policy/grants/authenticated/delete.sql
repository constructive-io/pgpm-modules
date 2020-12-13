-- Verify: schemas/collections_public/tables/policy/grants/authenticated/delete on pg

BEGIN;
SELECT verify_table_grant('collections_public.policy', 'delete', 'authenticated');
COMMIT;  

