-- Revert schemas/metaschema_public/tables/node_type_registry/fixtures/node_type_registry_seed from pg
--
-- GENERATED FILE — DO NOT EDIT
-- Regenerate with: cd packages/node-type-registry && pnpm generate

BEGIN;

DELETE FROM metaschema_public.node_type_registry;

COMMIT;
