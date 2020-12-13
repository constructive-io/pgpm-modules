-- Verify: schemas/collections_public/tables/table_grant/policies/authenticated_can_update_on_table_grant on pg

BEGIN;
SELECT verify_policy('authenticated_can_update_on_table_grant', 'collections_public.table_grant');
COMMIT;  

