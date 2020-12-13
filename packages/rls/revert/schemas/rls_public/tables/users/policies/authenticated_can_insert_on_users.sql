-- Revert: schemas/rls_public/tables/users/policies/authenticated_can_insert_on_users from pg

BEGIN;
DROP POLICY authenticated_can_insert_on_users ON "rls_public".users;
COMMIT;  

