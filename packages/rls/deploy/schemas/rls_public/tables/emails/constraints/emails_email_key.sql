-- Deploy: schemas/rls_public/tables/emails/constraints/emails_email_key to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/emails/table

BEGIN;

ALTER TABLE "rls_public".emails
    ADD CONSTRAINT emails_email_key UNIQUE (email);
COMMIT;
