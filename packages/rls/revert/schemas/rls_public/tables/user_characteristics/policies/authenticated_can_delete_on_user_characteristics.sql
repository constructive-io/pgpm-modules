-- Revert: schemas/rls_public/tables/user_characteristics/policies/authenticated_can_delete_on_user_characteristics from pg

BEGIN;
DROP POLICY authenticated_can_delete_on_user_characteristics ON "rls_public".user_characteristics;
COMMIT;  

