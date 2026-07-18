-- Deploy schemas/services_public/tables/managed_domains/table to pg

-- requires: schemas/services_public/schema
-- requires: schemas/metaschema_public/tables/database/table

BEGIN;

CREATE TABLE services_public.managed_domains (
    id uuid PRIMARY KEY DEFAULT uuidv7(),
    database_id uuid NOT NULL,

    domain hostname NOT NULL,
    is_wildcard boolean NOT NULL DEFAULT false,

    allow_public_usage boolean NOT NULL DEFAULT false,

    verification_status text NOT NULL DEFAULT 'pending',
    verified_at timestamptz,

    tls_status text NOT NULL DEFAULT 'none',
    tls_ready_at timestamptz,

    cert_status text NOT NULL DEFAULT 'none',

    annotations jsonb NOT NULL DEFAULT '{}',

    --
    CONSTRAINT db_fkey FOREIGN KEY (database_id) REFERENCES metaschema_public.database (id) ON DELETE CASCADE,
    CONSTRAINT verification_status_chk CHECK (verification_status IN ('pending', 'checking', 'verified', 'failed', 'expired')),
    CONSTRAINT tls_status_chk CHECK (tls_status IN ('none', 'provisioning', 'active', 'failed')),
    CONSTRAINT cert_status_chk CHECK (cert_status IN ('none', 'issuing', 'active', 'error')),
    UNIQUE ( domain )
);

COMMENT ON TABLE services_public.managed_domains IS 'One row per cert-bearing host or wildcard; tracks domain verification and TLS provisioning independently of services_public.domains. Reconcilers match a route''s root domain to a row here by string (no FK/coupling in v1)';
COMMENT ON COLUMN services_public.managed_domains.id IS 'Unique identifier for this managed domain record';
COMMENT ON COLUMN services_public.managed_domains.database_id IS 'Database that owns this cert-bearing host; platform wildcards are owned by the platform database';
COMMENT ON COLUMN services_public.managed_domains.domain IS 'Root hostname this row governs certs/verification for (e.g. launchql.dev, shop.acme.com)';
COMMENT ON COLUMN services_public.managed_domains.is_wildcard IS 'Whether the cert covers the wildcard *.domain (one wildcard cert covers every subdomain row sharing this root)';
COMMENT ON COLUMN services_public.managed_domains.allow_public_usage IS 'Whether this domain is deliberately published so routes in other scopes may match and ride this row''s cert. Only settable by app/platform authority via a generated AuthzColumnSecurity write-guard; backed by a generated permissive cross-scope SELECT policy.';
COMMENT ON COLUMN services_public.managed_domains.verification_status IS 'Domain ownership verification state driven by the domain:issue_challenge/domain:verify loop: pending | checking | verified | failed | expired';
COMMENT ON COLUMN services_public.managed_domains.verified_at IS 'When verification_status last became verified';
COMMENT ON COLUMN services_public.managed_domains.tls_status IS 'TLS/SSL serving/reconcile state (ingress): none | provisioning | active | failed';
COMMENT ON COLUMN services_public.managed_domains.tls_ready_at IS 'When tls_status last became active';
COMMENT ON COLUMN services_public.managed_domains.cert_status IS 'cert-manager resource lifecycle driven by the domain:issue_cert/domain:check_cert loop, tracked independently of tls_status: none | issuing | active | error';
COMMENT ON COLUMN services_public.managed_domains.annotations IS 'Freeform cert-manager detail (secret name, challenge, last error) and tooling metadata';

CREATE INDEX managed_domains_database_id_idx ON services_public.managed_domains ( database_id );

COMMIT;
