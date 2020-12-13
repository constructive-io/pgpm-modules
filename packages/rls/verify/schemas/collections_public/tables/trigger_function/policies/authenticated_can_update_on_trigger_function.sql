-- Verify: schemas/collections_public/tables/trigger_function/policies/authenticated_can_update_on_trigger_function on pg

BEGIN;
SELECT verify_policy('authenticated_can_update_on_trigger_function', 'collections_public.trigger_function');
COMMIT;  

