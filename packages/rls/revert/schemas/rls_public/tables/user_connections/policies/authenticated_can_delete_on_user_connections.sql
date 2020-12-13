-- Revert: schemas/rls_public/tables/user_connections/policies/authenticated_can_delete_on_user_connections from pg

BEGIN;
DROP POLICY authenticated_can_delete_on_user_connections ON "rls_public".user_connections;
COMMIT;  

