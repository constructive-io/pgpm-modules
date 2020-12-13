-- Deploy: schemas/rls_public/tables/user_characteristics/columns/user_id/alterations/alt0000000107 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/user_characteristics/table
-- requires: schemas/rls_public/tables/user_characteristics/columns/user_id/column

BEGIN;

ALTER TABLE "rls_public".user_characteristics 
    ALTER COLUMN user_id SET NOT NULL;
COMMIT;
