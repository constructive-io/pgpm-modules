-- Deploy schemas/secrets_schema/tables/secrets_table/table to pg

-- requires: schemas/secrets_schema/schema

BEGIN;

CREATE TABLE secrets_schema.secrets_table (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  secrets_owned_field uuid NOT NULL,
  name text NOT NULL,
  secrets_value_field bytea NULL,
  secrets_enc_field text NULL,
  UNIQUE(secrets_owned_field, name)
);

COMMENT ON TABLE secrets_schema.secrets_table IS 'Encrypted key-value secret storage: stores secrets as either raw bytea or encrypted text, scoped to an owning entity';
COMMENT ON COLUMN secrets_schema.secrets_table.id IS 'Unique identifier for this secret';
COMMENT ON COLUMN secrets_schema.secrets_table.secrets_owned_field IS 'UUID of the owning entity (e.g. user, organization); combined with name forms a unique key';
COMMENT ON COLUMN secrets_schema.secrets_table.name IS 'Name/key for this secret within its owner scope';
COMMENT ON COLUMN secrets_schema.secrets_table.secrets_value_field IS 'Raw binary secret value (mutually exclusive with secrets_enc_field)';
COMMENT ON COLUMN secrets_schema.secrets_table.secrets_enc_field IS 'Encrypted text secret value (mutually exclusive with secrets_value_field)';

COMMIT;
