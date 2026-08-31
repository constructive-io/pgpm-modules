-- Verify schemas/metaschema_public/tables/identity_provider_registry/table on pg

BEGIN;

SELECT slug, kind, display_name, issuer_url, authorization_url, token_url, userinfo_url, scopes
FROM metaschema_public.identity_provider_registry
WHERE FALSE;

ROLLBACK;
