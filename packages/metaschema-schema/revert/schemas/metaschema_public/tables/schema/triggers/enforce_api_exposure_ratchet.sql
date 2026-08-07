-- Revert schemas/metaschema_public/tables/schema/triggers/enforce_api_exposure_ratchet from pg

BEGIN;

DROP TRIGGER _000003_enforce_api_exposure_ratchet ON metaschema_public.schema;
DROP FUNCTION metaschema_public.tg_enforce_api_exposure_ratchet();

COMMIT;
