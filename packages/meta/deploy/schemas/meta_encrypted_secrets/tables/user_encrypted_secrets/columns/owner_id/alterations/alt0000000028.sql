-- Deploy: schemas/meta_encrypted_secrets/tables/user_encrypted_secrets/columns/owner_id/alterations/alt0000000028 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_encrypted_secrets/schema
-- requires: schemas/meta_encrypted_secrets/tables/user_encrypted_secrets/table
-- requires: schemas/meta_encrypted_secrets/tables/user_encrypted_secrets/columns/owner_id/column

BEGIN;

ALTER TABLE "meta_encrypted_secrets".user_encrypted_secrets 
    ALTER COLUMN owner_id SET NOT NULL;
COMMIT;
