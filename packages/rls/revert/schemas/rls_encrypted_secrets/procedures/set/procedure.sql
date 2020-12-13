-- Revert: schemas/rls_encrypted_secrets/procedures/set/procedure from pg

BEGIN;


DROP FUNCTION "rls_encrypted_secrets".set;
COMMIT;  

