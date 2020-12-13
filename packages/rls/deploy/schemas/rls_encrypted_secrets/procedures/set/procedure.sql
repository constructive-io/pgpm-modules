-- Deploy: schemas/rls_encrypted_secrets/procedures/set/procedure to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_encrypted_secrets/schema
-- requires: schemas/rls_encrypted_secrets/tables/user_encrypted_secrets/table
-- requires: schemas/rls_encrypted_secrets/tables/user_encrypted_secrets/columns/algo/column
-- requires: schemas/rls_encrypted_secrets/tables/user_encrypted_secrets/columns/value/column
-- requires: schemas/rls_encrypted_secrets/tables/user_encrypted_secrets/columns/owner_id/column

BEGIN;

CREATE FUNCTION "rls_encrypted_secrets".set (
  v_owner_id uuid,
  secret_name text,
  secret_value text,
  v_algo text = 'pgp'
)
  RETURNS boolean
  AS $$
BEGIN
  INSERT INTO "rls_encrypted_secrets".user_encrypted_secrets (owner_id, name, value, algo)
    VALUES (v_owner_id, set.secret_name, set.secret_value::bytea, set.v_algo)
    ON CONFLICT (owner_id, name)
    DO
    UPDATE
    SET
      value = set.secret_value::bytea,
      algo = EXCLUDED.algo;
  RETURN TRUE;
END
$$
LANGUAGE 'plpgsql'
VOLATILE;
GRANT EXECUTE ON FUNCTION "rls_encrypted_secrets".set TO authenticated;
COMMIT;
