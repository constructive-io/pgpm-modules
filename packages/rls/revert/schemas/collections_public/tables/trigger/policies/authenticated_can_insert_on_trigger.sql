-- Revert: schemas/collections_public/tables/trigger/policies/authenticated_can_insert_on_trigger from pg

BEGIN;
DROP POLICY authenticated_can_insert_on_trigger ON collections_public.trigger;
COMMIT;  

