-- Deploy: schemas/meta_public/tables/emails/columns/email/alterations/alt0000000039 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/emails/table
-- requires: schemas/meta_public/tables/emails/columns/email/column

BEGIN;

ALTER TABLE "meta_public".emails 
    ALTER COLUMN email SET NOT NULL;
COMMIT;
