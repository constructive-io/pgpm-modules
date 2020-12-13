-- Deploy: schemas/rls_roles_public/procedures/set_password/procedure to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_roles_public/schema
-- requires: schemas/rls_encrypted_secrets/schema
-- requires: schemas/rls_public/tables/users/table
-- requires: schemas/rls_simple_secrets/tables/user_secrets/table

BEGIN;

CREATE FUNCTION "rls_roles_public".set_password (
  current_password text,
  new_password text
)
  RETURNS boolean
  AS $$
DECLARE
  v_user "rls_public".users;
  v_user_secret "rls_simple_secrets".user_secrets;
  password_exists boolean;
BEGIN
  IF (new_password IS NULL) THEN 
    RAISE EXCEPTION 'PASSWORD_LEN';
  END IF;
  new_password = trim(new_password);
  IF (character_length(new_password) <= 7 OR character_length(new_password) >= 64) THEN 
    RAISE EXCEPTION 'PASSWORD_LEN';
  END IF;
  SELECT
    u.* INTO v_user
  FROM
    "rls_public".users AS u
  WHERE
    id = "rls_roles_public".get_current_user_id ();
  IF (NOT FOUND) THEN
    RETURN FALSE;
  END IF;
  SELECT EXISTS (
    SELECT 1
      FROM "rls_encrypted_secrets".user_encrypted_secrets
      WHERE owner_id=v_user.id
        AND name='password_hash'
  )
  INTO password_exists;
  IF (password_exists IS TRUE) THEN 
    IF ("rls_encrypted_secrets".verify(
        v_user.id,
        'password_hash',
        current_password
    ) IS FALSE) THEN 
      RAISE EXCEPTION 'INCORRECT_PASSWORD';
    END IF;
  END IF;
  PERFORM "rls_encrypted_secrets".set
    (v_user.id, 'password_hash', new_password, 'crypt');
      
  RETURN TRUE;
END;
$$
LANGUAGE 'plpgsql'
VOLATILE;
GRANT EXECUTE ON FUNCTION "rls_roles_public".set_password TO authenticated;
COMMIT;
