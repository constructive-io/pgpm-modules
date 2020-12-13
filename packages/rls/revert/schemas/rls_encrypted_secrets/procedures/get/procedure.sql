-- Revert: schemas/rls_encrypted_secrets/procedures/get/procedure from pg

BEGIN;


DROP FUNCTION "rls_encrypted_secrets".get;
COMMIT;  

