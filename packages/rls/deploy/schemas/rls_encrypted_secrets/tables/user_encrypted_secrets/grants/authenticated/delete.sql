-- Deploy: schemas/rls_encrypted_secrets/tables/user_encrypted_secrets/grants/authenticated/delete to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_encrypted_secrets/schema
-- requires: schemas/rls_encrypted_secrets/tables/user_encrypted_secrets/table

BEGIN;
GRANT DELETE ON TABLE "rls_encrypted_secrets".user_encrypted_secrets TO authenticated;
COMMIT;
