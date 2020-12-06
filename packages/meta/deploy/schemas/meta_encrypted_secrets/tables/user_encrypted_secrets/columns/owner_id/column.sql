-- Deploy: schemas/meta_encrypted_secrets/tables/user_encrypted_secrets/columns/owner_id/column to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_encrypted_secrets/schema
-- requires: schemas/meta_encrypted_secrets/tables/user_encrypted_secrets/table

BEGIN;

ALTER TABLE "meta_encrypted_secrets".user_encrypted_secrets ADD COLUMN owner_id uuid;
COMMIT;
