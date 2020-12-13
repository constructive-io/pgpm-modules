-- Deploy: schemas/rls_encrypted_secrets/tables/user_encrypted_secrets/triggers/user_encrypted_secrets_update_tg to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_encrypted_secrets/schema
-- requires: schemas/rls_encrypted_secrets/tables/user_encrypted_secrets/table
-- requires: schemas/rls_encrypted_secrets/trigger_fns/user_encrypted_secrets_hash

BEGIN;

CREATE TRIGGER user_encrypted_secrets_update_tg
BEFORE UPDATE ON "rls_encrypted_secrets".user_encrypted_secrets
FOR EACH ROW
  WHEN (
    NEW.value IS DISTINCT FROM OLD.value
  )
EXECUTE PROCEDURE "rls_encrypted_secrets".user_encrypted_secrets_hash ();
COMMIT;
