-- Deploy: schemas/rls_public/tables/user_profiles/indexes/user_profiles_user_id_idx to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/user_profiles/table

BEGIN;

CREATE INDEX user_profiles_user_id_idx ON "rls_public".user_profiles (user_id);
COMMIT;
