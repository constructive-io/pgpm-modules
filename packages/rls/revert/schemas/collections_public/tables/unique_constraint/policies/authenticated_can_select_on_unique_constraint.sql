-- Revert: schemas/collections_public/tables/unique_constraint/policies/authenticated_can_select_on_unique_constraint from pg

BEGIN;
DROP POLICY authenticated_can_select_on_unique_constraint ON collections_public.unique_constraint;
COMMIT;  

