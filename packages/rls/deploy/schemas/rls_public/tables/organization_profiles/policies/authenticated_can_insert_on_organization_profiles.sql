-- Deploy: schemas/rls_public/tables/organization_profiles/policies/authenticated_can_insert_on_organization_profiles to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/organization_profiles/table
-- requires: schemas/rls_public/tables/organization_profiles/policies/enable_row_level_security

BEGIN;
CREATE POLICY authenticated_can_insert_on_organization_profiles ON "rls_public".organization_profiles FOR INSERT TO authenticated WITH CHECK ( organization_id = "rls_roles_public".get_current_user_id() );
COMMIT;
