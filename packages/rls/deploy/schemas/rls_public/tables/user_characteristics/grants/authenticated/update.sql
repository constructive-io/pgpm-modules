-- Deploy: schemas/rls_public/tables/user_characteristics/grants/authenticated/update to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/user_characteristics/table

BEGIN;
GRANT UPDATE ON TABLE "rls_public".user_characteristics TO authenticated;
COMMIT;
