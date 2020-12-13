-- Deploy: schemas/rls_private/procedures/uuid_generate_seeded_uuid/grants/public to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_private/schema
-- requires: schemas/rls_private/procedures/uuid_generate_seeded_uuid/procedure

BEGIN;

GRANT EXECUTE ON FUNCTION
    "rls_private".uuid_generate_seeded_uuid
TO public;
COMMIT;
