-- Revert: schemas/rls_public/tables/user_profiles/policies/authenticated_can_update_on_user_profiles from pg

BEGIN;
DROP POLICY authenticated_can_update_on_user_profiles ON "rls_public".user_profiles;
COMMIT;  

