-- Deploy: schemas/rls_public/tables/emails/columns/id/alterations/alt0000000039 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/emails/table
-- requires: schemas/rls_public/tables/emails/columns/id/column

BEGIN;

ALTER TABLE "rls_public".emails 
    ALTER COLUMN id SET DEFAULT "rls_private".uuid_generate_v4();
COMMIT;
