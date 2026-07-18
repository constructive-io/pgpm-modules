-- Deploy schemas/services_public/tables/domain_events/table to pg

-- requires: schemas/services_public/schema
-- requires: schemas/services_public/tables/managed_domains/table
-- requires: schemas/services_public/tables/domain_verifications/table

BEGIN;

-- Append-only audit trail for the domain verify->DNS->issue loop, mirroring the
-- shape of compute_public.resource_events / cluster_events (id, created_at,
-- <subject>_id, event_type, actor_id, message, metadata). resource_events is
-- partitioned+retained by its module generator's partition-lifecycle wiring;
-- these hand-authored services tables have no such maintenance wiring, so
-- domain_events is a plain append-only table (matching managed_domains, which is
-- also unpartitioned). Partitioning/retention can be layered on later alongside
-- the module-generator lifecycle if event volume warrants it.
CREATE TABLE services_public.domain_events (
    id uuid PRIMARY KEY DEFAULT uuidv7(),
    owner_id uuid NOT NULL,
    managed_domain_id uuid NOT NULL,
    domain_verification_id uuid,

    event_type text NOT NULL,
    actor_id uuid,
    message text,
    metadata jsonb NOT NULL DEFAULT '{}',

    created_at timestamptz NOT NULL DEFAULT now(),

    --
    CONSTRAINT managed_domain_fkey FOREIGN KEY (managed_domain_id) REFERENCES services_public.managed_domains (id) ON DELETE CASCADE,
    CONSTRAINT domain_verification_fkey FOREIGN KEY (domain_verification_id) REFERENCES services_public.domain_verifications (id) ON DELETE SET NULL,
    CONSTRAINT event_type_chk CHECK (event_type IN (
        'challenge_issued',
        'verification_started',
        'verified',
        'verification_failed',
        'verification_expired',
        'cert_issuing',
        'cert_active',
        'cert_error',
        'cert_renewed',
        'cert_revoked'
    ))
);

COMMENT ON TABLE services_public.domain_events IS 'Append-only audit trail of the domain verify->DNS->issue lifecycle, mirroring resource_events / cluster_events. One row per state transition emitted by the domain:* functions.';
COMMENT ON COLUMN services_public.domain_events.id IS 'Unique event identifier';
COMMENT ON COLUMN services_public.domain_events.owner_id IS 'Entity (e.g. org) that owns the managed_domain; scope key for AuthzEntityMembership RLS';
COMMENT ON COLUMN services_public.domain_events.managed_domain_id IS 'The managed_domain this event belongs to';
COMMENT ON COLUMN services_public.domain_events.domain_verification_id IS 'The verification challenge this event relates to, when applicable';
COMMENT ON COLUMN services_public.domain_events.event_type IS 'Lifecycle event: challenge_issued | verification_started | verified | verification_failed | verification_expired | cert_issuing | cert_active | cert_error | cert_renewed | cert_revoked';
COMMENT ON COLUMN services_public.domain_events.actor_id IS 'User who triggered this event (NULL for system/automated transitions)';
COMMENT ON COLUMN services_public.domain_events.message IS 'Human-readable description of the event';
COMMENT ON COLUMN services_public.domain_events.metadata IS 'Structured context (challenge record, cert-manager detail, error details, ...)';
COMMENT ON COLUMN services_public.domain_events.created_at IS 'Event timestamp';

CREATE INDEX domain_events_owner_id_idx ON services_public.domain_events ( owner_id );

CREATE INDEX domain_events_managed_domain_id_created_at_idx ON services_public.domain_events ( managed_domain_id, created_at );

CREATE INDEX domain_events_domain_verification_id_idx ON services_public.domain_events ( domain_verification_id );

COMMIT;
