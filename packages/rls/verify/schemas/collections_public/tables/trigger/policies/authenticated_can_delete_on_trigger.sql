-- Verify: schemas/collections_public/tables/trigger/policies/authenticated_can_delete_on_trigger on pg

BEGIN;
SELECT verify_policy('authenticated_can_delete_on_trigger', 'collections_public.trigger');
COMMIT;  

