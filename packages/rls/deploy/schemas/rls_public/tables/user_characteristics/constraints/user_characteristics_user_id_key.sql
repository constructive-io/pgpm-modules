-- Deploy: schemas/rls_public/tables/user_characteristics/constraints/user_characteristics_user_id_key to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/user_characteristics/table

BEGIN;

ALTER TABLE "rls_public".user_characteristics
    ADD CONSTRAINT user_characteristics_user_id_key UNIQUE (user_id);
COMMIT;
