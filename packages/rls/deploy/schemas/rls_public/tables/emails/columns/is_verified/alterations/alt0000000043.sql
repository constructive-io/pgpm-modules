-- Deploy: schemas/rls_public/tables/emails/columns/is_verified/alterations/alt0000000043 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/emails/table
-- requires: schemas/rls_public/tables/emails/columns/is_verified/column

BEGIN;

ALTER TABLE "rls_public".emails 
    ALTER COLUMN is_verified SET DEFAULT false;
COMMIT;
