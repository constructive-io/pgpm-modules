-- Deploy: schemas/rls_encrypted_secrets/procedures/verify/procedure to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_encrypted_secrets/schema
-- requires: schemas/rls_encrypted_secrets/tables/user_encrypted_secrets/table
-- requires: schemas/rls_encrypted_secrets/tables/user_encrypted_secrets/columns/algo/column
-- requires: schemas/rls_encrypted_secrets/tables/user_encrypted_secrets/columns/owner_id/column

BEGIN;

CREATE FUNCTION "rls_encrypted_secrets".verify (
  owner_id uuid,
  secret_name text,
  value text
)
  RETURNS boolean
  AS $$
DECLARE
  v_secret_text text;
  v_secret "rls_encrypted_secrets".user_encrypted_secrets;
BEGIN
  SELECT
    *
  FROM
    "rls_encrypted_secrets".get (verify.owner_id, verify.secret_name)
  INTO v_secret_text;
  SELECT
    *
  FROM
    "rls_encrypted_secrets".user_encrypted_secrets s
  WHERE
    s.name = verify.secret_name
    AND s.owner_id = verify.owner_id INTO v_secret;
  IF (v_secret.algo = 'crypt') THEN
    RETURN v_secret_text = crypt(verify.value::bytea::text, v_secret_text);
  ELSIF (v_secret.algo = 'pgp') THEN
    RETURN verify.value = v_secret_text;
  END IF;
  RETURN verify.value = v_secret_text;
END
$$
LANGUAGE 'plpgsql'
STABLE;
GRANT EXECUTE ON FUNCTION "rls_encrypted_secrets".verify TO authenticated;
COMMIT;
