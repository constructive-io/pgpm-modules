-- Deploy schemas/metaschema_public/tables/identity_provider_registry/table to pg

-- requires: schemas/metaschema_public/schema

BEGIN;

-- Catalog of built-in identity providers. Each row is the protocol metadata
-- for one built-in IdP; provisioning reads this table and seeds a tenant
-- catalog row per provider (credentials NULL, enabled false) so nothing is
-- offered for sign-in until an admin configures it. Adding a provider or
-- correcting an endpoint is an INSERT/UPDATE here, not a code change.
CREATE TABLE metaschema_public.identity_provider_registry (
  slug text PRIMARY KEY,
  -- 'oidc' rows carry issuer_url (endpoints resolve via discovery);
  -- 'oauth2' rows carry the three explicit endpoint URLs.
  kind text NOT NULL CHECK (kind IN ('oauth2', 'oidc')),
  display_name text NOT NULL,
  issuer_url text,
  authorization_url text,
  token_url text,
  userinfo_url text,
  scopes text[] NOT NULL DEFAULT '{}'::text[],
  CHECK (
    (kind = 'oidc' AND issuer_url IS NOT NULL)
    OR (kind = 'oauth2'
      AND authorization_url IS NOT NULL
      AND token_url IS NOT NULL
      AND userinfo_url IS NOT NULL)
  )
);

COMMIT;
