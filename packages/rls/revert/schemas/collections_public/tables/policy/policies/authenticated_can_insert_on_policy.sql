-- Revert: schemas/collections_public/tables/policy/policies/authenticated_can_insert_on_policy from pg

BEGIN;
DROP POLICY authenticated_can_insert_on_policy ON collections_public.policy;
COMMIT;  

