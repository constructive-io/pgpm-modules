-- Verify: schemas/collections_public/tables/field/policies/authenticated_can_select_on_field on pg

BEGIN;
SELECT verify_policy('authenticated_can_select_on_field', 'collections_public.field');
COMMIT;  

