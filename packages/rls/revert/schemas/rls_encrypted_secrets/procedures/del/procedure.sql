-- Revert: schemas/rls_encrypted_secrets/procedures/del/procedure from pg

BEGIN;


DROP FUNCTION "rls_encrypted_secrets".del;
COMMIT;  

