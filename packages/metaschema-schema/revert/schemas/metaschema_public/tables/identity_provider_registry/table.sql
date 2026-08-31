-- Revert schemas/metaschema_public/tables/identity_provider_registry/table from pg

BEGIN;

DROP TABLE IF EXISTS metaschema_public.identity_provider_registry;

COMMIT;
