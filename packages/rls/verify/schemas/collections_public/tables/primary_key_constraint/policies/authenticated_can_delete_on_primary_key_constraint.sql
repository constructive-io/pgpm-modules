-- Verify: schemas/collections_public/tables/primary_key_constraint/policies/authenticated_can_delete_on_primary_key_constraint on pg

BEGIN;
SELECT verify_policy('authenticated_can_delete_on_primary_key_constraint', 'collections_public.primary_key_constraint');
COMMIT;  

