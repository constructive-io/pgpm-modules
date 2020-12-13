-- Revert: schemas/rls_roles_public/procedures/get_current_user_id/procedure from pg

BEGIN;


DROP FUNCTION "rls_roles_public".get_current_user_id;

COMMIT;  

