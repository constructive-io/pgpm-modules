-- Deploy: schemas/meta_public/tables/emails/columns/id/alterations/alt0000000036 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/emails/table
-- requires: schemas/meta_public/tables/emails/columns/id/column

BEGIN;

ALTER TABLE "meta_public".emails 
    ALTER COLUMN id SET NOT NULL;
COMMIT;
