-- Deploy: schemas/meta_public/procedures/reset_password/procedure to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_encrypted_secrets/schema
-- requires: schemas/meta_public/tables/users/table
-- requires: schemas/meta_encrypted_secrets/tables/user_encrypted_secrets/table

BEGIN;

CREATE FUNCTION "meta_public".reset_password (role_id uuid, reset_token text, new_password text)
    RETURNS boolean
AS $$
DECLARE
    v_user "meta_public".users;
    
    v_reset_max_interval interval = interval '3 days';
    v_reset_max_attempts int = 10;
    reset_password_attempts int;
    first_failed_reset_password_attempt timestamptz;
BEGIN
    IF (role_id IS NULL OR reset_token IS NULL OR new_password IS NULL) THEN
        RAISE EXCEPTION 'NULL_VALUES_DISALLOWED';
    END IF;
    SELECT
        u.* INTO v_user
    FROM
        "meta_public".users as u
    WHERE
        id = role_id;
    IF (NOT FOUND) THEN
      RETURN NULL;
    END IF;
    reset_password_attempts = "meta_simple_secrets".get(v_user.id, 'reset_password_attempts', '0');
    first_failed_reset_password_attempt = "meta_simple_secrets".get(v_user.id, 'first_failed_reset_password_attempt');
    IF (first_failed_reset_password_attempt IS NOT NULL
      AND NOW() < first_failed_reset_password_attempt + v_reset_max_interval
      AND reset_password_attempts >= v_reset_max_attempts) THEN
        RAISE
        EXCEPTION 'PASSWORD_RESET_LOCKED_EXCEED_ATTEMPTS';
    END IF;
    IF ("meta_encrypted_secrets".verify(v_user.id, 'reset_password_token', reset_token)) THEN
        PERFORM "meta_encrypted_secrets".set
            (v_user.id, 'password_hash', new_password, 'crypt');
        PERFORM "meta_simple_secrets".del(
            v_user.id,
            ARRAY[
                'password_attempts',
                'first_failed_password_attempt',
                'reset_password_token_generated',
                'reset_password_attempts',
                'first_failed_reset_password_attempt'                
            ]
        );
        PERFORM "meta_encrypted_secrets".del(
            v_user.id,
            'reset_password_token'
        );
        RETURN TRUE;
    ELSE
        IF (
            first_failed_reset_password_attempt IS NULL OR
            first_failed_reset_password_attempt + v_reset_max_interval < NOW() 
        ) THEN
            reset_password_attempts = 1;
            first_failed_reset_password_attempt = NOW();
        ELSE 
            reset_password_attempts = reset_password_attempts + 1;
        END IF;
        PERFORM "meta_simple_secrets".set(v_user.id, 'reset_password_attempts', reset_password_attempts);
        PERFORM "meta_simple_secrets".set(v_user.id, 'first_failed_reset_password_attempt', first_failed_reset_password_attempt);
    END IF;
    RETURN FALSE;
END;
$$
LANGUAGE 'plpgsql' VOLATILE
SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION "meta_public".reset_password to anonymous;
REVOKE EXECUTE ON FUNCTION "meta_public".reset_password from authenticated;
COMMIT;
