-- Verify: schemas/rls_public/tables/user_profiles/policies/authenticated_can_select_on_user_profiles on pg

BEGIN;
SELECT verify_policy('authenticated_can_select_on_user_profiles', 'rls_public.user_profiles');
COMMIT;  

