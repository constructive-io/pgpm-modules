-- Revert: schemas/rls_roles_public/procedures/forgot_password/procedure from pg

BEGIN;


DROP FUNCTION "rls_roles_public".forgot_password;
COMMIT;  

