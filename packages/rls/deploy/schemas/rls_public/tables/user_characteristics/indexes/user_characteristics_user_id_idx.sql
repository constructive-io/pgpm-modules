-- Deploy: schemas/rls_public/tables/user_characteristics/indexes/user_characteristics_user_id_idx to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_public/schema
-- requires: schemas/rls_public/tables/user_characteristics/table

BEGIN;

CREATE INDEX user_characteristics_user_id_idx ON "rls_public".user_characteristics (user_id);
COMMIT;
