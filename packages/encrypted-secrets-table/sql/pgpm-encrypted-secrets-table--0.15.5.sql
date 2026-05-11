\echo Use "CREATE EXTENSION pgpm-encrypted-secrets-table" to load this file. \quit
CREATE SCHEMA secrets_schema;

CREATE TABLE secrets_schema.secrets_table (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  secrets_owned_field uuid NOT NULL,
  name text NOT NULL,
  secrets_value_field bytea NULL,
  secrets_enc_field text NULL,
  UNIQUE (secrets_owned_field, name)
);

COMMENT ON TABLE secrets_schema.secrets_table IS 'Encrypted key-value secret storage: stores secrets as either raw bytea or encrypted text, scoped to an owning entity';

COMMENT ON COLUMN secrets_schema.secrets_table.id IS 'Unique identifier for this secret';

COMMENT ON COLUMN secrets_schema.secrets_table.secrets_owned_field IS 'UUID of the owning entity (e.g. user, organization); combined with name forms a unique key';

COMMENT ON COLUMN secrets_schema.secrets_table.name IS 'Name/key for this secret within its owner scope';

COMMENT ON COLUMN secrets_schema.secrets_table.secrets_value_field IS 'Raw binary secret value (mutually exclusive with secrets_enc_field)';

COMMENT ON COLUMN secrets_schema.secrets_table.secrets_enc_field IS 'Encrypted text secret value (mutually exclusive with secrets_value_field)';

CREATE FUNCTION secrets_schema.tg_hash_secrets() RETURNS trigger AS $EOFCODE$
BEGIN
    IF (NEW.secrets_enc_field = 'crypt') THEN
        NEW.secrets_value_field = crypt(NEW.secrets_value_field::text, gen_salt('bf'));
    ELSIF (NEW.secrets_enc_field = 'pgp') THEN
        NEW.secrets_value_field = pgp_sym_encrypt(encode(NEW.secrets_value_field::bytea, 'hex'), NEW.secrets_owned_field::text, 'compress-algo=1, cipher-algo=aes256');
    ELSE
        NEW.secrets_enc_field = 'none';
    END IF;
    RETURN NEW;
END;
$EOFCODE$ LANGUAGE plpgsql VOLATILE;

CREATE TRIGGER hash_secrets_update
  BEFORE UPDATE
  ON secrets_schema.secrets_table
  FOR EACH ROW
  WHEN (new.secrets_value_field IS DISTINCT FROM old.secrets_value_field)
  EXECUTE PROCEDURE secrets_schema.tg_hash_secrets();

CREATE TRIGGER hash_secrets_insert
  BEFORE INSERT
  ON secrets_schema.secrets_table
  FOR EACH ROW
  EXECUTE PROCEDURE secrets_schema.tg_hash_secrets();