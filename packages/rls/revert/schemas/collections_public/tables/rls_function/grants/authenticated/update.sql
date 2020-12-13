-- Revert: schemas/collections_public/tables/rls_function/grants/authenticated/update from pg

BEGIN;
REVOKE UPDATE ON TABLE collections_public.rls_function FROM authenticated;
COMMIT;  

