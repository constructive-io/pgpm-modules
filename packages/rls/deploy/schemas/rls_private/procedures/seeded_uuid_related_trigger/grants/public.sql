-- Deploy: schemas/rls_private/procedures/seeded_uuid_related_trigger/grants/public to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_private/schema
-- requires: schemas/rls_private/procedures/seeded_uuid_related_trigger/procedure

BEGIN;

GRANT EXECUTE ON FUNCTION
    "rls_private".seeded_uuid_related_trigger
TO public;
COMMIT;
