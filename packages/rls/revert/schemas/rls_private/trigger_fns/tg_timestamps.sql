-- Revert: schemas/rls_private/trigger_fns/tg_timestamps from pg

BEGIN;


DROP FUNCTION "rls_private".tg_timestamps();
COMMIT;  

