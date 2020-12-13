-- Deploy: schemas/rls_encrypted_secrets/tables/user_encrypted_secrets/policies/enable_row_level_security to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_encrypted_secrets/schema
-- requires: schemas/rls_encrypted_secrets/tables/user_encrypted_secrets/table

BEGIN;

ALTER TABLE "rls_encrypted_secrets".user_encrypted_secrets
    ENABLE ROW LEVEL SECURITY;
COMMIT;
