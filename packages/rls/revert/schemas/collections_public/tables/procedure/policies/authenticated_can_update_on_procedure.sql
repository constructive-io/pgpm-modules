-- Revert: schemas/collections_public/tables/procedure/policies/authenticated_can_update_on_procedure from pg

BEGIN;
DROP POLICY authenticated_can_update_on_procedure ON collections_public.procedure;
COMMIT;  

