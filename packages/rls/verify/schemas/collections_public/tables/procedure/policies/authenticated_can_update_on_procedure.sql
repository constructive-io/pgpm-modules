-- Verify: schemas/collections_public/tables/procedure/policies/authenticated_can_update_on_procedure on pg

BEGIN;
SELECT verify_policy('authenticated_can_update_on_procedure', 'collections_public.procedure');
COMMIT;  

