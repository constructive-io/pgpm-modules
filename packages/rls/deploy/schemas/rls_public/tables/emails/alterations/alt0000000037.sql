-- Deploy: schemas/rls_public/tables/emails/alterations/alt0000000037 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/emails/table

BEGIN;

ALTER TABLE "rls_public".emails
    DISABLE ROW LEVEL SECURITY;
COMMIT;
