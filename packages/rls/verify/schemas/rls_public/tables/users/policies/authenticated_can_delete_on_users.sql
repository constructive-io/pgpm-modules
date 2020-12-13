-- Verify: schemas/rls_public/tables/users/policies/authenticated_can_delete_on_users on pg

BEGIN;
SELECT verify_policy('authenticated_can_delete_on_users', 'rls_public.users');
COMMIT;  

