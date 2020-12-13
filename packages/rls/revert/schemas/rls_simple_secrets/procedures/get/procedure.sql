-- Revert: schemas/rls_simple_secrets/procedures/get/procedure from pg

BEGIN;


DROP FUNCTION "rls_simple_secrets".get;
COMMIT;  

