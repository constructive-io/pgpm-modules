-- Revert: schemas/rls_roles_public/procedures/login/procedure from pg

BEGIN;


DROP FUNCTION "rls_roles_public".login;
COMMIT;  

