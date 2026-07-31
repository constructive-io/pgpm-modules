-- Revert schemas/metaschema_public/tables/derives/table from pg

BEGIN;

DROP TABLE IF EXISTS metaschema_public.derives;

COMMIT;
