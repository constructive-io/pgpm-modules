-- Deploy: schemas/rls_public/tables/user_profiles/policies/authenticated_can_select_on_user_profiles to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/user_profiles/table
-- requires: schemas/rls_public/tables/user_profiles/policies/enable_row_level_security

BEGIN;
CREATE POLICY authenticated_can_select_on_user_profiles ON "rls_public".user_profiles FOR SELECT TO authenticated USING ( TRUE );
COMMIT;
