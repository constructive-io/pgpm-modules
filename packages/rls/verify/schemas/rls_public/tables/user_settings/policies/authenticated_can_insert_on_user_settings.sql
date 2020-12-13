-- Verify: schemas/rls_public/tables/user_settings/policies/authenticated_can_insert_on_user_settings on pg

BEGIN;
SELECT verify_policy('authenticated_can_insert_on_user_settings', 'rls_public.user_settings');
COMMIT;  

