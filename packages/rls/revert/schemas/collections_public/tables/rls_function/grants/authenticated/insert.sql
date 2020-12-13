-- Revert: schemas/collections_public/tables/rls_function/grants/authenticated/insert from pg

BEGIN;
REVOKE INSERT ON TABLE collections_public.rls_function FROM authenticated;
COMMIT;  

