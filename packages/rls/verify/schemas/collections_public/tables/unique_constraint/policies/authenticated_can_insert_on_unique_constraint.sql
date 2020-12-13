-- Verify: schemas/collections_public/tables/unique_constraint/policies/authenticated_can_insert_on_unique_constraint on pg

BEGIN;
SELECT verify_policy('authenticated_can_insert_on_unique_constraint', 'collections_public.unique_constraint');
COMMIT;  

