-- Revert: schemas/rls_private/procedures/uuid_generate_v4/grants/public from pg

BEGIN;


REVOKE EXECUTE ON FUNCTION
    "rls_private".uuid_generate_v4
FROM public;
COMMIT;  

