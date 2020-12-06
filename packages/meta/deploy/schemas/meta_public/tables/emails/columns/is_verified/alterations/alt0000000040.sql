-- Deploy: schemas/meta_public/tables/emails/columns/is_verified/alterations/alt0000000040 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/emails/table
-- requires: schemas/meta_public/tables/emails/columns/is_verified/column

BEGIN;

ALTER TABLE "meta_public".emails 
    ALTER COLUMN is_verified SET NOT NULL;
COMMIT;
