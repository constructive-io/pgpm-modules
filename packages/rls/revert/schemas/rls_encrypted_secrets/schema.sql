-- Revert: schemas/rls_encrypted_secrets/schema from pg

BEGIN;


DROP SCHEMA IF EXISTS "rls_encrypted_secrets" CASCADE;
COMMIT;  

