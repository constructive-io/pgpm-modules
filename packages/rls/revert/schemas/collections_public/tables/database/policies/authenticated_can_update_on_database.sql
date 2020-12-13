-- Revert: schemas/collections_public/tables/database/policies/authenticated_can_update_on_database from pg

BEGIN;
DROP POLICY authenticated_can_update_on_database ON collections_public.database;
COMMIT;  

