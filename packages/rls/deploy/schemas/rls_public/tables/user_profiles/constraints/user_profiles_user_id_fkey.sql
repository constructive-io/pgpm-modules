-- Deploy: schemas/rls_public/tables/user_profiles/constraints/user_profiles_user_id_fkey to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/users/table
-- requires: schemas/rls_public/tables/user_profiles/table
-- requires: schemas/rls_public/tables/users/columns/id/column
-- requires: schemas/rls_public/tables/user_profiles/columns/user_id/column

BEGIN;

ALTER TABLE "rls_public".user_profiles 
    ADD CONSTRAINT user_profiles_user_id_fkey 
    FOREIGN KEY (user_id)
    REFERENCES "rls_public".users (id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION;
COMMIT;
