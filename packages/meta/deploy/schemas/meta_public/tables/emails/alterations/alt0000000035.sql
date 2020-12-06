-- Deploy: schemas/meta_public/tables/emails/alterations/alt0000000035 to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/emails/table

BEGIN;

ALTER TABLE "meta_public".emails
    DISABLE ROW LEVEL SECURITY;
COMMIT;
