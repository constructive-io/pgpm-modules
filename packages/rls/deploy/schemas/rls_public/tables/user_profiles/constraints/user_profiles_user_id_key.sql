-- Deploy: schemas/rls_public/tables/user_profiles/constraints/user_profiles_user_id_key to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/user_profiles/table

BEGIN;

ALTER TABLE "rls_public".user_profiles
    ADD CONSTRAINT user_profiles_user_id_key UNIQUE (user_id);
COMMIT;
