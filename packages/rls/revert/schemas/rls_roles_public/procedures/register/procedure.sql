-- Revert: schemas/rls_roles_public/procedures/register/procedure from pg

BEGIN;


DROP FUNCTION "rls_roles_public".register;

COMMIT;  

