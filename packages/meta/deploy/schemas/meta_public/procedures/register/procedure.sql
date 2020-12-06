-- Deploy: schemas/meta_public/procedures/register/procedure to pg
-- made with <3 @ launchql.com

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_encrypted_secrets/schema
-- requires: schemas/meta_public/tables/users/table
-- requires: schemas/meta_public/tables/emails/table
-- requires: schemas/meta_private/tables/api_tokens/table

BEGIN;

CREATE FUNCTION "meta_public".register (
  email text,
  password text
)
  RETURNS "meta_private".api_tokens
  AS $$
DECLARE
  v_user "meta_public".users;
  v_email "meta_public".emails;
  v_token "meta_private".api_tokens;
BEGIN
  IF (password IS NULL) THEN 
    RAISE EXCEPTION 'PASSWORD_LEN';
  END IF;
  password = trim(password);
  IF (character_length(password) <= 7 OR character_length(password) >= 64) THEN 
    RAISE EXCEPTION 'PASSWORD_LEN';
  END IF;
  SELECT * FROM "meta_public".emails t
    WHERE trim(register.email)::email = t.email
  INTO v_email;
  IF (NOT FOUND) THEN
    INSERT INTO "meta_public".users
      DEFAULT VALUES
    RETURNING
      * INTO v_user;
    INSERT INTO "meta_public".emails (owner_id, email)
      VALUES (v_user.id, trim(register.email))
    RETURNING
      * INTO v_email;
    INSERT INTO "meta_private".api_tokens (user_id)
      VALUES (v_user.id)
    RETURNING
      * INTO v_token;
    PERFORM "meta_encrypted_secrets".set
      (v_user.id, 'password_hash', trim(password), 'crypt');
    RETURN v_token;
  END IF;
  RAISE EXCEPTION 'ACCOUNT_EXISTS';
END;
$$
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION "meta_public".register TO anonymous;
COMMIT;
