-- Verify: schemas/collections_public/tables/schema_grant/policies/authenticated_can_select_on_schema_grant on pg

BEGIN;
SELECT verify_policy('authenticated_can_select_on_schema_grant', 'collections_public.schema_grant');
COMMIT;  

