-- Revert: schemas/rls_encrypted_secrets/procedures/verify/procedure from pg

BEGIN;


DROP FUNCTION "rls_encrypted_secrets".verify;
COMMIT;  

