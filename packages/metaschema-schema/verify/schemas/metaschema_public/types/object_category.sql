-- Verify schemas/metaschema_public/types/object_category on pg

BEGIN;

SELECT 'core'::metaschema_public.object_category;

ROLLBACK;
