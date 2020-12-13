-- Deploy: schemas/rls_public/tables/emails/columns/email/column to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/emails/table

BEGIN;

ALTER TABLE "rls_public".emails ADD COLUMN email email;
COMMIT;
