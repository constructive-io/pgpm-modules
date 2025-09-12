-- Revert procedures/test from pg

BEGIN;

DELETE FROM meta_public.site_themes WHERE database_id IN (SELECT id FROM collections_public.database WHERE name = 'meta_db');
DELETE FROM meta_public.site_metadata WHERE database_id IN (SELECT id FROM collections_public.database WHERE name = 'meta_db');
DELETE FROM meta_public.rls_module WHERE database_id IN (SELECT id FROM collections_public.database WHERE name = 'meta_db');
DELETE FROM meta_public.user_auth_module WHERE database_id IN (SELECT id FROM collections_public.database WHERE name = 'meta_db');
DELETE FROM meta_public.api_extensions WHERE database_id IN (SELECT id FROM collections_public.database WHERE name = 'meta_db');
DELETE FROM meta_public.api_schemata WHERE database_id IN (SELECT id FROM collections_public.database WHERE name = 'meta_db');
DELETE FROM meta_public.domains WHERE database_id IN (SELECT id FROM collections_public.database WHERE name = 'meta_db');
DELETE FROM meta_public.apps WHERE database_id IN (SELECT id FROM collections_public.database WHERE name = 'meta_db');
DELETE FROM meta_public.sites WHERE database_id IN (SELECT id FROM collections_public.database WHERE name = 'meta_db');
DELETE FROM meta_public.apis WHERE database_id IN (SELECT id FROM collections_public.database WHERE name = 'meta_db');
DELETE FROM collections_public.table WHERE database_id IN (SELECT id FROM collections_public.database WHERE name = 'meta_db');
DELETE FROM collections_public.schema WHERE database_id IN (SELECT id FROM collections_public.database WHERE name = 'meta_db');
DELETE FROM collections_public.database WHERE name = 'meta_db';

COMMIT;
