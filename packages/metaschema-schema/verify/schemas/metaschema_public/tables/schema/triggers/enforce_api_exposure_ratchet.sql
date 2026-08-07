-- Verify schemas/metaschema_public/tables/schema/triggers/enforce_api_exposure_ratchet on pg

BEGIN;

SELECT assert_function('metaschema_public.tg_enforce_api_exposure_ratchet()'::regprocedure);

ROLLBACK;
