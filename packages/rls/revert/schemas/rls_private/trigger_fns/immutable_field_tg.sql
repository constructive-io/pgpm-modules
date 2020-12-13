-- Revert: schemas/rls_private/trigger_fns/immutable_field_tg from pg

BEGIN;


DROP FUNCTION "rls_private".immutable_field_tg;
COMMIT;  

