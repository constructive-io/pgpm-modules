-- Revert: schemas/rls_private/trigger_fns/tg_peoplestamps from pg

BEGIN;


DROP FUNCTION "rls_private".tg_peoplestamps();
COMMIT;  

