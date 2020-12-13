-- Revert: schemas/rls_simple_secrets/procedures/set/procedure from pg

BEGIN;


DROP FUNCTION "rls_simple_secrets".set;
COMMIT;  

