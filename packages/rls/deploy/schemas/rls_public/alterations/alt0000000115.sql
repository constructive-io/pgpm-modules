-- Deploy: schemas/rls_public/alterations/alt0000000115 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema

BEGIN;
COMMENT ON COLUMN "rls_public".user_contacts.device IS E'originating device type or id';
COMMIT;
