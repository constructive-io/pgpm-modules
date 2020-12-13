-- Revert: schemas/rls_private/procedures/uuid_generate_v4/procedure from pg

BEGIN;


DROP FUNCTION "rls_private".uuid_generate_v4;
COMMIT;  

