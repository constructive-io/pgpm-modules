-- Deploy: schemas/meta_public/procedures/forgot_password/procedure to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/users/table

BEGIN;

CREATE FUNCTION "meta_public".forgot_password (email email)
    RETURNS void
AS $$
DECLARE
    v_email "meta_public".emails;
    v_user_id uuid;
    v_reset_token text;
    v_reset_min_duration_between_emails interval = interval '3 minutes';
    
    v_reset_max_duration interval = interval '3 days';
    password_reset_email_sent_at timestamptz;
BEGIN
    SELECT * FROM "meta_public".emails e
        WHERE e.email = forgot_password.email::email
    INTO v_email;
    IF (NOT FOUND) THEN
        RETURN;
    END IF;
    v_user_id = v_email.owner_id;
    password_reset_email_sent_at = "meta_simple_secrets".get(v_user_id, 'password_reset_email_sent_at');
    IF (
        password_reset_email_sent_at IS NOT NULL AND
        NOW() < password_reset_email_sent_at + v_reset_min_duration_between_emails
    ) THEN 
        RETURN;
    END IF;
    v_reset_token = encode(gen_random_bytes(7), 'hex');
    PERFORM "meta_encrypted_secrets".set
        (v_user_id, 'reset_password_token', v_reset_token, 'crypt');
    PERFORM "meta_simple_secrets".set(v_user_id, 'password_reset_email_sent_at', (NOW())::text);
    PERFORM
        app_jobs.add_job ('user__forgot_password',
            json_build_object('user_id', v_user_id, 'email', v_email.email::text, 'token', v_reset_token));
    RETURN;
END;
$$
LANGUAGE 'plpgsql' VOLATILE
SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION "meta_public".forgot_password TO anonymous;
COMMIT;
