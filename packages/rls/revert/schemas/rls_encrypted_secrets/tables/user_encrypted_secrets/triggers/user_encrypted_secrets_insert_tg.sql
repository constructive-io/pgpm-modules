-- Revert: schemas/rls_encrypted_secrets/tables/user_encrypted_secrets/triggers/user_encrypted_secrets_insert_tg from pg

BEGIN;


DROP TRIGGER user_encrypted_secrets_insert_tg
    ON "rls_encrypted_secrets".user_encrypted_secrets;
COMMIT;  

