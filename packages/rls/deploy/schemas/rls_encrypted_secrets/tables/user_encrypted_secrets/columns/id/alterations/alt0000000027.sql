-- Deploy: schemas/rls_encrypted_secrets/tables/user_encrypted_secrets/columns/id/alterations/alt0000000027 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_encrypted_secrets/schema
-- requires: schemas/rls_encrypted_secrets/tables/user_encrypted_secrets/table
-- requires: schemas/rls_encrypted_secrets/tables/user_encrypted_secrets/columns/id/column

BEGIN;

ALTER TABLE "rls_encrypted_secrets".user_encrypted_secrets 
    ALTER COLUMN id SET DEFAULT "rls_private".uuid_generate_v4();
COMMIT;
