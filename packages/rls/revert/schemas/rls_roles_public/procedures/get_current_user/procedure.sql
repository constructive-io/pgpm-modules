-- Revert: schemas/rls_roles_public/procedures/get_current_user/procedure from pg

BEGIN;


DROP FUNCTION "rls_roles_public".get_current_user;
COMMIT;  

