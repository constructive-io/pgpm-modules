-- Verify: schemas/rls_public/tables/organization_settings/policies/authenticated_can_select_on_organization_settings on pg

BEGIN;
SELECT verify_policy('authenticated_can_select_on_organization_settings', 'rls_public.organization_settings');
COMMIT;  

