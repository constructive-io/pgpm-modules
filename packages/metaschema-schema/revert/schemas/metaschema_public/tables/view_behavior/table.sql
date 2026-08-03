-- Revert schemas/metaschema_public/tables/view_behavior/table from pg

BEGIN;

DROP TABLE metaschema_public.view_behavior;

COMMIT;
