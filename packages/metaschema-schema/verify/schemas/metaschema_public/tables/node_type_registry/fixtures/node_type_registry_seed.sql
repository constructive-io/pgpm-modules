-- Verify schemas/metaschema_public/tables/node_type_registry/fixtures/node_type_registry_seed on pg

BEGIN;

SELECT 1 FROM metaschema_public.node_type_registry WHERE name = 'AuthzDirectOwner';

ROLLBACK;
