-- Revert: schemas/collections_public/tables/schema/policies/authenticated_can_update_on_schema from pg

BEGIN;
DROP POLICY authenticated_can_update_on_schema ON collections_public.schema;
COMMIT;  

