-- Deploy: schemas/rls_public/tables/emails/columns/email/alterations/alt0000000041 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/emails/table
-- requires: schemas/rls_public/tables/emails/columns/email/column

BEGIN;

ALTER TABLE "rls_public".emails 
    ALTER COLUMN email SET NOT NULL;
COMMIT;
