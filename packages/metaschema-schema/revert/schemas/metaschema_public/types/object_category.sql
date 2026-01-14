-- Revert schemas/metaschema_public/types/object_category from pg

BEGIN;

DROP TYPE IF EXISTS metaschema_public.object_category;

COMMIT;
