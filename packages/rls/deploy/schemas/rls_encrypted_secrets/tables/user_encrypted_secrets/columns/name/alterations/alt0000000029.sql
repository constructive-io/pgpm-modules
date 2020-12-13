-- Deploy: schemas/rls_encrypted_secrets/tables/user_encrypted_secrets/columns/name/alterations/alt0000000029 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_encrypted_secrets/schema
-- requires: schemas/rls_encrypted_secrets/tables/user_encrypted_secrets/table
-- requires: schemas/rls_encrypted_secrets/tables/user_encrypted_secrets/columns/name/column

BEGIN;

ALTER TABLE "rls_encrypted_secrets".user_encrypted_secrets 
    ALTER COLUMN name SET NOT NULL;
COMMIT;
