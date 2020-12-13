-- Revert: schemas/rls_private/procedures/seeded_uuid_related_trigger/grants/public from pg

BEGIN;


REVOKE EXECUTE ON FUNCTION
    "rls_private".seeded_uuid_related_trigger
FROM public;
COMMIT;  

