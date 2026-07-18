-- Deploy schemas/services_private/procedures/domain_issue_challenge to pg

-- requires: schemas/services_private/schema
-- requires: schemas/services_public/tables/managed_domains/table
-- requires: schemas/services_public/tables/domain_verifications/table
-- requires: schemas/services_public/tables/domain_events/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/database/table

BEGIN;

-- domain:issue_challenge — first node of the verify->DNS->issue loop.
--
-- Mints a fresh PUBLIC verification challenge for a managed_domain, records the
-- record the user must publish in services_public.domain_verifications, moves
-- the domain's verification_status back to 'pending', and emits a
-- 'challenge_issued' audit event. The record_value is a verification token that
-- ends up in a public DNS record — it is NOT a secret and lives in a table, not
-- the secrets module.
--
-- Any still-outstanding challenge for the same (managed_domain, method) is
-- expired first so exactly one challenge is active at a time. This is a static
-- function (no dynamic SQL); it is invoked directly, by a job trigger, or by
-- the runtime='sql' worker dispatch registered under the domain:issue_challenge
-- task identifier.
CREATE FUNCTION services_private.domain_issue_challenge(
    v_managed_domain_id uuid,
    v_method text DEFAULT 'dns_txt_ownership',
    v_actor_id uuid DEFAULT NULL
) RETURNS services_public.domain_verifications AS $$
DECLARE
    v_owner_id uuid;
    v_domain text;
    v_token text;
    v_record_name text;
    v_record_type text;
    v_record_value text;
    v_row services_public.domain_verifications;
BEGIN
    -- The verification/audit rows are entity-owned (owner_id), so resolve the
    -- owning entity from the managed_domain's database owner. managed_domains
    -- itself stays database-scoped; only this loop's tables key on the entity.
    SELECT db.owner_id, md.domain
      INTO v_owner_id, v_domain
      FROM services_public.managed_domains AS md
      JOIN metaschema_public.database AS db ON db.id = md.database_id
     WHERE md.id = v_managed_domain_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'DOMAIN_ISSUE_CHALLENGE_UNKNOWN_DOMAIN: no managed_domain with id %', v_managed_domain_id
            USING ERRCODE = 'foreign_key_violation';
    END IF;

    IF v_owner_id IS NULL THEN
        RAISE EXCEPTION 'DOMAIN_ISSUE_CHALLENGE_NO_OWNER: managed_domain % has no owning entity', v_managed_domain_id
            USING ERRCODE = 'not_null_violation';
    END IF;

    IF v_method NOT IN ('dns_txt_ownership', 'http_01', 'dns_01_acme') THEN
        RAISE EXCEPTION 'DOMAIN_ISSUE_CHALLENGE_BAD_METHOD: unsupported verification method %', v_method
            USING ERRCODE = 'check_violation';
    END IF;

    -- 256 bits of entropy as a 64-char hex token; gen_random_uuid is core in
    -- PostgreSQL (no pgcrypto dependency needed for the services module).
    v_token := replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');

    IF v_method = 'dns_txt_ownership' THEN
        v_record_name := '_constructive-challenge.' || v_domain;
        v_record_type := 'TXT';
        v_record_value := 'constructive-domain-verification=' || v_token;
    ELSIF v_method = 'dns_01_acme' THEN
        v_record_name := '_acme-challenge.' || v_domain;
        v_record_type := 'TXT';
        v_record_value := v_token;
    ELSE
        -- http_01: served at /.well-known/acme-challenge/<token>, no DNS record.
        v_record_name := NULL;
        v_record_type := NULL;
        v_record_value := v_token;
    END IF;

    -- Supersede any outstanding challenge for this (domain, method) so only one
    -- is ever active; historical rows stay for the audit trail.
    UPDATE services_public.domain_verifications
       SET status = 'expired',
           updated_at = now()
     WHERE managed_domain_id = v_managed_domain_id
       AND method = v_method
       AND status IN ('pending', 'checking');

    INSERT INTO services_public.domain_verifications
        (owner_id, managed_domain_id, method, record_name, record_type, record_value,
         status, attempts, expires_at)
    VALUES
        (v_owner_id, v_managed_domain_id, v_method, v_record_name, v_record_type, v_record_value,
         'pending', 0, now() + interval '7 days')
    RETURNING * INTO v_row;

    UPDATE services_public.managed_domains
       SET verification_status = 'pending'
     WHERE id = v_managed_domain_id;

    INSERT INTO services_public.domain_events
        (owner_id, managed_domain_id, domain_verification_id, event_type, actor_id, message, metadata)
    VALUES
        (v_owner_id, v_managed_domain_id, v_row.id, 'challenge_issued', v_actor_id,
         'Issued ' || v_method || ' verification challenge for ' || v_domain,
         jsonb_build_object(
            'method', v_method,
            'record_name', v_record_name,
            'record_type', v_record_type,
            'record_value', v_record_value
         ));

    RETURN v_row;
END;
$$ LANGUAGE plpgsql VOLATILE SECURITY DEFINER;

COMMENT ON FUNCTION services_private.domain_issue_challenge(uuid, text, uuid) IS 'domain:issue_challenge — mints a public verification challenge, writes the domain_verifications row + challenge_issued event, and resets managed_domains.verification_status to pending.';

GRANT EXECUTE ON FUNCTION services_private.domain_issue_challenge(uuid, text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION services_private.domain_issue_challenge(uuid, text, uuid) TO administrator;

COMMIT;
