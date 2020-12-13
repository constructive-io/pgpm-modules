-- Verify: schemas/collections_public/tables/rls_function/policies/authenticated_can_delete_on_rls_function on pg

BEGIN;
SELECT verify_policy('authenticated_can_delete_on_rls_function', 'collections_public.rls_function');
COMMIT;  

