-- Revert: schemas/rls_private/procedures/seeded_uuid_related_trigger/procedure from pg

BEGIN;


DROP FUNCTION "rls_private".seeded_uuid_related_trigger;
COMMIT;  

