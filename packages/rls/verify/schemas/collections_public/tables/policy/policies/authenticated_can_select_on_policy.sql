-- Verify: schemas/collections_public/tables/policy/policies/authenticated_can_select_on_policy on pg

BEGIN;
SELECT verify_policy('authenticated_can_select_on_policy', 'collections_public.policy');
COMMIT;  

