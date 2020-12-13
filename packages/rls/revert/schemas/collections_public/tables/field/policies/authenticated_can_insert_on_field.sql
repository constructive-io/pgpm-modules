-- Revert: schemas/collections_public/tables/field/policies/authenticated_can_insert_on_field from pg

BEGIN;
DROP POLICY authenticated_can_insert_on_field ON collections_public.field;
COMMIT;  

