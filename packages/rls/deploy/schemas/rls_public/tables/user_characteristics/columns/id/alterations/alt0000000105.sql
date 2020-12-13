-- Deploy: schemas/rls_public/tables/user_characteristics/columns/id/alterations/alt0000000105 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/user_characteristics/table
-- requires: schemas/rls_public/tables/user_characteristics/columns/id/column

BEGIN;

ALTER TABLE "rls_public".user_characteristics 
    ALTER COLUMN id SET NOT NULL;
COMMIT;
