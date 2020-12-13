-- Deploy: schemas/rls_roles_public/procedures/send_verification_email/procedure to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_roles_public/schema
-- requires: schemas/rls_encrypted_secrets/schema

BEGIN;

CREATE FUNCTION "rls_roles_public".send_verification_email(email email)
RETURNS boolean AS $$
DECLARE
  v_email "rls_public".emails;
  v_user_id uuid;
  v_verification_token text;
  v_verification_min_duration_between_emails interval = interval '3 minutes';
  v_verification_min_duration_between_new_tokens interval = interval '10 minutes';
  verification_token_name text;
  verification_email_sent_at timestamptz;
BEGIN
  SELECT * FROM "rls_public".emails e
    WHERE e.email = send_verification_email.email
  INTO v_email;
  IF (NOT FOUND) THEN 
    RETURN FALSE;
  END IF;
  verification_token_name = v_email.email::text || '_verification_token';
  IF ( v_email.is_verified IS TRUE ) THEN
    PERFORM "rls_simple_secrets".del(v_email.owner_id, ARRAY[
        'verification_email_sent_at',
        'verification_email_attempts',
        'first_failed_verification_email_attempt'
    ]);
    PERFORM "rls_encrypted_secrets".del(v_email.owner_id, ARRAY[
        verification_token_name
    ]);
    RETURN FALSE;
  END IF;
  v_user_id = v_email.owner_id;
  verification_email_sent_at = "rls_simple_secrets".get(v_user_id, 'verification_email_sent_at');
    IF (
      verification_email_sent_at IS NOT NULL AND
      NOW() < verification_email_sent_at + v_verification_min_duration_between_emails
    ) THEN 
        RETURN NULL;
    END IF;
  
  IF (
    verification_email_sent_at IS NOT NULL AND
    NOW() < verification_email_sent_at + v_verification_min_duration_between_new_tokens 
  ) THEN 
    v_verification_token = "rls_encrypted_secrets".get
        (v_user_id, verification_token_name, encode(gen_random_bytes(10), 'hex'));
  ELSE
    v_verification_token = encode(gen_random_bytes(10), 'hex');
  END IF;
  verification_email_sent_at = NOW();
  PERFORM "rls_simple_secrets".set
    (v_user_id, 'verification_email_sent_at', verification_email_sent_at);
  PERFORM "rls_encrypted_secrets".set
    (v_user_id, verification_token_name, v_verification_token, 'pgp');
  PERFORM
      app_jobs.add_job ('send_email_link',
        json_build_object(
          'email_type', 'email_verification',
          'email_id', v_email.id,
          'email', email,
          'verification_token', v_verification_token
        )
      );
  RETURN TRUE;
END;
$$
LANGUAGE 'plpgsql' VOLATILE SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION "rls_roles_public".send_verification_email TO authenticated, anonymous;
COMMIT;
