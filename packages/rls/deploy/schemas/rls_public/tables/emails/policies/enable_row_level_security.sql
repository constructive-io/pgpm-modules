-- Deploy: schemas/rls_public/tables/emails/policies/enable_row_level_security to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/emails/table

BEGIN;

ALTER TABLE "rls_public".emails
    ENABLE ROW LEVEL SECURITY;
COMMIT;
