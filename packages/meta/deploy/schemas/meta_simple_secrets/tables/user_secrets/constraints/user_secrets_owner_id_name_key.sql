-- Deploy: schemas/meta_simple_secrets/tables/user_secrets/constraints/user_secrets_owner_id_name_key to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_simple_secrets/schema
-- requires: schemas/meta_simple_secrets/tables/user_secrets/table

BEGIN;

ALTER TABLE "meta_simple_secrets".user_secrets
    ADD CONSTRAINT user_secrets_owner_id_name_key UNIQUE (owner_id,name);
COMMIT;
