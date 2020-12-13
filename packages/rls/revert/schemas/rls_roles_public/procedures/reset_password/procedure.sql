-- Revert: schemas/rls_roles_public/procedures/reset_password/procedure from pg

BEGIN;


DROP FUNCTION "rls_roles_public".reset_password;

COMMIT;  

