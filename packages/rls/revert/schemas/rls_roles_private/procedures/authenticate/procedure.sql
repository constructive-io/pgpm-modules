-- Revert: schemas/rls_roles_private/procedures/authenticate/procedure from pg

BEGIN;


DROP FUNCTION "rls_roles_private".authenticate;
COMMIT;  

