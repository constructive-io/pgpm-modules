-- Deploy: schemas/rls_encrypted_secrets/tables/user_encrypted_secrets/columns/id/column to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_encrypted_secrets/schema
-- requires: schemas/rls_encrypted_secrets/tables/user_encrypted_secrets/table

BEGIN;

ALTER TABLE "rls_encrypted_secrets".user_encrypted_secrets ADD COLUMN id uuid;
COMMIT;
