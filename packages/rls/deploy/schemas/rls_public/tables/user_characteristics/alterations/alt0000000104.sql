-- Deploy: schemas/rls_public/tables/user_characteristics/alterations/alt0000000104 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/user_characteristics/table

BEGIN;

ALTER TABLE "rls_public".user_characteristics
    DISABLE ROW LEVEL SECURITY;
COMMIT;
