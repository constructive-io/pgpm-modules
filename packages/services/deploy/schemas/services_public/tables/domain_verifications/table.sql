-- Deploy schemas/services_public/tables/domain_verifications/table to pg

-- requires: schemas/services_public/schema
-- requires: schemas/services_public/tables/managed_domains/table

BEGIN;

CREATE TABLE services_public.domain_verifications (
    id uuid PRIMARY KEY DEFAULT uuidv7(),
    owner_id uuid NOT NULL,
    managed_domain_id uuid NOT NULL,

    method text NOT NULL DEFAULT 'dns_txt_ownership',

    record_name text,
    record_type text,
    record_value text,

    status text NOT NULL DEFAULT 'pending',
    attempts integer NOT NULL DEFAULT 0,

    last_checked_at timestamptz,
    verified_at timestamptz,
    expires_at timestamptz,
    error text,

    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),

    --
    CONSTRAINT managed_domain_fkey FOREIGN KEY (managed_domain_id) REFERENCES services_public.managed_domains (id) ON DELETE CASCADE,
    CONSTRAINT method_chk CHECK (method IN ('dns_txt_ownership', 'http_01', 'dns_01_acme')),
    CONSTRAINT record_type_chk CHECK (record_type IS NULL OR record_type IN ('TXT', 'CNAME', 'A')),
    CONSTRAINT status_chk CHECK (status IN ('pending', 'checking', 'verified', 'failed', 'expired'))
);

COMMENT ON TABLE services_public.domain_verifications IS 'One row per outstanding/completed ownership-verification challenge for a managed_domain. Holds the PUBLIC challenge the user must publish (e.g. a DNS TXT record value) — this is a verification token, NOT a secret. Entity-owned via owner_id and read/written through the AuthzEntityMembership scoped-module security path gated on manage_domains.';
COMMENT ON COLUMN services_public.domain_verifications.id IS 'Unique identifier for this verification challenge';
COMMENT ON COLUMN services_public.domain_verifications.owner_id IS 'Entity (e.g. org) that owns this verification; scope key for AuthzEntityMembership RLS. Domain control is proven once per owning entity.';
COMMENT ON COLUMN services_public.domain_verifications.managed_domain_id IS 'The managed_domain this challenge proves ownership of';
COMMENT ON COLUMN services_public.domain_verifications.method IS 'Verification method: dns_txt_ownership (root-domain ownership TXT) | http_01 (ACME HTTP challenge) | dns_01_acme (ACME DNS challenge)';
COMMENT ON COLUMN services_public.domain_verifications.record_name IS 'DNS record name the user must create (e.g. _constructive-challenge.example.com); NULL for http_01';
COMMENT ON COLUMN services_public.domain_verifications.record_type IS 'DNS record type to create: TXT | CNAME | A; NULL for http_01';
COMMENT ON COLUMN services_public.domain_verifications.record_value IS 'The public challenge token the user must publish (ends up in a public DNS record). NOT a secret.';
COMMENT ON COLUMN services_public.domain_verifications.status IS 'Challenge lifecycle: pending | checking | verified | failed | expired';
COMMENT ON COLUMN services_public.domain_verifications.attempts IS 'Number of times domain:verify has polled for this challenge (drives backoff / max_attempts)';
COMMENT ON COLUMN services_public.domain_verifications.last_checked_at IS 'When domain:verify last polled DNS/HTTP for this challenge';
COMMENT ON COLUMN services_public.domain_verifications.verified_at IS 'When status last became verified';
COMMENT ON COLUMN services_public.domain_verifications.expires_at IS 'When this challenge expires and must be reissued';
COMMENT ON COLUMN services_public.domain_verifications.error IS 'Last verification error (mismatch, NXDOMAIN, timeout, ...)';
COMMENT ON COLUMN services_public.domain_verifications.created_at IS 'When this challenge was minted (domain:issue_challenge)';
COMMENT ON COLUMN services_public.domain_verifications.updated_at IS 'When this row was last updated';

CREATE INDEX domain_verifications_owner_id_idx ON services_public.domain_verifications ( owner_id );

CREATE INDEX domain_verifications_managed_domain_id_idx ON services_public.domain_verifications ( managed_domain_id );

COMMIT;
