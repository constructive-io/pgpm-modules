-- Revert: schemas/rls_private/procedures/uuid_generate_seeded_uuid/procedure from pg

BEGIN;


DROP FUNCTION "rls_private".uuid_generate_seeded_uuid;
COMMIT;  

