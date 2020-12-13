-- Deploy: schemas/rls_public/alterations/alt0000000114 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema

BEGIN;
COMMENT ON COLUMN "rls_public".user_contacts.full_name IS E'full name of the person or business';
COMMIT;
