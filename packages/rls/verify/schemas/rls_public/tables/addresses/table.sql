-- Verify: schemas/rls_public/tables/addresses/table on pg

BEGIN;
SELECT verify_table('rls_public.addresses');
COMMIT;  

