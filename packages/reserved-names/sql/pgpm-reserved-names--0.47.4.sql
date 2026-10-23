\echo Use "CREATE EXTENSION pgpm-reserved-names" to load this file. \quit
CREATE SCHEMA reserved_names;

GRANT USAGE ON SCHEMA reserved_names TO PUBLIC;

CREATE TABLE reserved_names.names (
  kind text NOT NULL CHECK (kind ~ '^[a-z][a-z0-9_]*$'),
  name text NOT NULL CHECK (
    name <> ''
      AND name = lower(name)
  ),
  is_prefix boolean NOT NULL DEFAULT false,
  reason text,
  PRIMARY KEY (kind, name)
);

COMMENT ON TABLE reserved_names.names IS 'Names nobody may claim, grouped by kind (subdomain, username, slug, ...). Changed only by migrations.';

COMMENT ON COLUMN reserved_names.names.kind IS 'What kind of name this reserves, e.g. subdomain or username';

COMMENT ON COLUMN reserved_names.names.name IS 'The reserved name, lowercase';

COMMENT ON COLUMN reserved_names.names.is_prefix IS 'When true, every name starting with this one is reserved too';

COMMENT ON COLUMN reserved_names.names.reason IS 'Why the name is reserved';

GRANT SELECT ON reserved_names.names TO PUBLIC;

CREATE FUNCTION reserved_names.is_reserved(
  kind text,
  name text
) RETURNS boolean AS $EOFCODE$
  SELECT EXISTS (
    SELECT 1
      FROM reserved_names.names n
     WHERE n.kind = is_reserved.kind
       AND (n.name = pg_catalog.lower(is_reserved.name)
            OR (n.is_prefix AND pg_catalog.starts_with(pg_catalog.lower(is_reserved.name), n.name)))
  );
$EOFCODE$ LANGUAGE sql STABLE;

COMMENT ON FUNCTION reserved_names.is_reserved(text, text) IS 'True when name (any case) is reserved for kind, exactly or by a prefix entry';

GRANT EXECUTE ON FUNCTION reserved_names.is_reserved(text, text) TO PUBLIC;

INSERT INTO reserved_names.names (
  kind,
  name,
  reason
) SELECT
  'subdomain',
  label,
  'platform'
FROM unnest(ARRAY['www', 'api', 'auth', 'login', 'logout', 'signin', 'signup', 'register', 'admin', 'administrator', 'root', 'app', 'apps', 'dashboard', 'console', 'account', 'accounts', 'billing', 'pay', 'payments', 'checkout', 'support', 'help', 'status', 'docs', 'mail', 'email', 'smtp', 'imap', 'ftp', 'ns', 'ns1', 'ns2', 'mx', 'cdn', 'static', 'assets', 'files', 'storage', 'media', 'ws', 'wss', 'graphql', 'modules', 'agent', 'compute', 'machines', 'cluster', 'migrate', 'internal', 'system', 'platform', 'security', 'sso', 'oauth', 'id', 'identity', 'verify', 'secure']) AS label;

INSERT INTO reserved_names.names (
  kind,
  name,
  is_prefix,
  reason
) VALUES
  ('subdomain', 'xn--', true, 'punycode lookalikes');