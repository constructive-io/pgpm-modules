-- Verify: schemas/collections_public/tables/schema/policies/authenticated_can_select_on_schema on pg

BEGIN;
SELECT verify_policy('authenticated_can_select_on_schema', 'collections_public.schema');
COMMIT;  

