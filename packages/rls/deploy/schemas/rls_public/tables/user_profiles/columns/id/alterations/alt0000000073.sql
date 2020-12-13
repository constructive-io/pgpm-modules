-- Deploy: schemas/rls_public/tables/user_profiles/columns/id/alterations/alt0000000073 to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/user_profiles/table
-- requires: schemas/rls_public/tables/user_profiles/columns/id/column

BEGIN;

ALTER TABLE "rls_public".user_profiles 
    ALTER COLUMN id SET DEFAULT "rls_private".uuid_generate_v4();
COMMIT;
