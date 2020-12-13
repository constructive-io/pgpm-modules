-- Revert: schemas/rls_roles_public/procedures/set_password/procedure from pg

BEGIN;


DROP FUNCTION "rls_roles_public".set_password;
COMMIT;  

