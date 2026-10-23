\echo Use "CREATE EXTENSION pgpm-reserved-names" to load this file. \quit
CREATE SCHEMA reserved_names;

GRANT USAGE ON SCHEMA reserved_names TO PUBLIC;

CREATE TABLE reserved_names.kinds (
  kind text PRIMARY KEY CHECK (kind ~ '^[a-z][a-z0-9_]*$'),
  description text NOT NULL
);

COMMENT ON TABLE reserved_names.kinds IS 'Categories of names that can be reserved: subdomain, username, domain, slug, ...';

GRANT SELECT ON reserved_names.kinds TO PUBLIC;

CREATE TABLE reserved_names.reasons (
  reason text PRIMARY KEY CHECK (reason ~ '^[a-z][a-z0-9_]*$'),
  description text NOT NULL
);

COMMENT ON TABLE reserved_names.reasons IS 'Why a name is reserved: platform, brand, lookalike, abuse, ...';

GRANT SELECT ON reserved_names.reasons TO PUBLIC;

CREATE TABLE reserved_names.names (
  kind text NOT NULL REFERENCES reserved_names.kinds (kind),
  name text NOT NULL CHECK (
    name <> ''
      AND name = lower(name)
  ),
  match text NOT NULL DEFAULT 'exact' CHECK (match IN ('exact', 'prefix', 'suffix')),
  reason text NOT NULL REFERENCES reserved_names.reasons (reason),
  PRIMARY KEY (kind, name, match)
);

COMMENT ON TABLE reserved_names.names IS 'Names nobody may claim, by kind. Changed only by migrations.';

COMMENT ON COLUMN reserved_names.names.name IS 'The reserved name, lowercase';

COMMENT ON COLUMN reserved_names.names.match IS 'exact: the name itself; prefix: every name starting with it; suffix: every name ending with it';

GRANT SELECT ON reserved_names.names TO PUBLIC;

CREATE INDEX names_reason_idx ON reserved_names.names (reason);

CREATE FUNCTION reserved_names.reserved_by(
  kind text,
  name text
) RETURNS SETOF reserved_names.names AS $EOFCODE$
  SELECT n.*
    FROM reserved_names.names n
   WHERE n.kind = pg_catalog.lower(reserved_by.kind)
     AND CASE n.match
           WHEN 'exact'  THEN n.name = pg_catalog.lower(reserved_by.name)
           WHEN 'prefix' THEN pg_catalog.starts_with(pg_catalog.lower(reserved_by.name), n.name)
           WHEN 'suffix' THEN pg_catalog.right(pg_catalog.lower(reserved_by.name), pg_catalog.length(n.name)) = n.name
         END;
$EOFCODE$ LANGUAGE sql STABLE;

COMMENT ON FUNCTION reserved_names.reserved_by(text, text) IS 'The entries (with their reason) that reserve name for kind; empty when it is free';

GRANT EXECUTE ON FUNCTION reserved_names.reserved_by(text, text) TO PUBLIC;

CREATE FUNCTION reserved_names.is_reserved(
  kind text,
  name text
) RETURNS boolean AS $EOFCODE$
  SELECT EXISTS (SELECT 1 FROM reserved_names.reserved_by(is_reserved.kind, is_reserved.name));
$EOFCODE$ LANGUAGE sql STABLE;

COMMENT ON FUNCTION reserved_names.is_reserved(text, text) IS 'True when name (any case) is reserved for kind';

GRANT EXECUTE ON FUNCTION reserved_names.is_reserved(text, text) TO PUBLIC;

INSERT INTO reserved_names.kinds (
  kind,
  description
) VALUES
  ('subdomain', 'A label under a shared domain, like login in login.example.com'),
  ('username', 'A person''s handle'),
  ('domain', 'A whole domain name, like example.com'),
  ('slug', 'A name in a URL path, like an organization or app slug');

INSERT INTO reserved_names.reasons (
  reason,
  description
) VALUES
  ('platform', 'Reads as the platform''s own (login, admin, status, ...)'),
  ('brand', 'Our brand or product names'),
  ('lookalike', 'Can be made to look like another name, e.g. punycode'),
  ('abuse', 'Offensive or used for abuse');

INSERT INTO reserved_names.names (
  kind,
  name,
  match,
  reason
) VALUES
  ('subdomain', 'www', 'exact', 'platform'),
  ('subdomain', 'api', 'exact', 'platform'),
  ('subdomain', 'auth', 'exact', 'platform'),
  ('subdomain', 'login', 'exact', 'platform'),
  ('subdomain', 'logout', 'exact', 'platform'),
  ('subdomain', 'signin', 'exact', 'platform'),
  ('subdomain', 'signup', 'exact', 'platform'),
  ('subdomain', 'register', 'exact', 'platform'),
  ('subdomain', 'admin', 'exact', 'platform'),
  ('subdomain', 'administrator', 'exact', 'platform'),
  ('subdomain', 'root', 'exact', 'platform'),
  ('subdomain', 'app', 'exact', 'platform'),
  ('subdomain', 'apps', 'exact', 'platform'),
  ('subdomain', 'dashboard', 'exact', 'platform'),
  ('subdomain', 'console', 'exact', 'platform'),
  ('subdomain', 'account', 'exact', 'platform'),
  ('subdomain', 'accounts', 'exact', 'platform'),
  ('subdomain', 'billing', 'exact', 'platform'),
  ('subdomain', 'pay', 'exact', 'platform'),
  ('subdomain', 'payments', 'exact', 'platform'),
  ('subdomain', 'checkout', 'exact', 'platform'),
  ('subdomain', 'support', 'exact', 'platform'),
  ('subdomain', 'help', 'exact', 'platform'),
  ('subdomain', 'status', 'exact', 'platform'),
  ('subdomain', 'docs', 'exact', 'platform'),
  ('subdomain', 'mail', 'exact', 'platform'),
  ('subdomain', 'email', 'exact', 'platform'),
  ('subdomain', 'smtp', 'exact', 'platform'),
  ('subdomain', 'imap', 'exact', 'platform'),
  ('subdomain', 'ftp', 'exact', 'platform'),
  ('subdomain', 'ns', 'exact', 'platform'),
  ('subdomain', 'ns1', 'exact', 'platform'),
  ('subdomain', 'ns2', 'exact', 'platform'),
  ('subdomain', 'mx', 'exact', 'platform'),
  ('subdomain', 'cdn', 'exact', 'platform'),
  ('subdomain', 'static', 'exact', 'platform'),
  ('subdomain', 'assets', 'exact', 'platform'),
  ('subdomain', 'files', 'exact', 'platform'),
  ('subdomain', 'storage', 'exact', 'platform'),
  ('subdomain', 'media', 'exact', 'platform'),
  ('subdomain', 'ws', 'exact', 'platform'),
  ('subdomain', 'wss', 'exact', 'platform'),
  ('subdomain', 'graphql', 'exact', 'platform'),
  ('subdomain', 'modules', 'exact', 'platform'),
  ('subdomain', 'agent', 'exact', 'platform'),
  ('subdomain', 'compute', 'exact', 'platform'),
  ('subdomain', 'machines', 'exact', 'platform'),
  ('subdomain', 'cluster', 'exact', 'platform'),
  ('subdomain', 'migrate', 'exact', 'platform'),
  ('subdomain', 'internal', 'exact', 'platform'),
  ('subdomain', 'system', 'exact', 'platform'),
  ('subdomain', 'platform', 'exact', 'platform'),
  ('subdomain', 'security', 'exact', 'platform'),
  ('subdomain', 'sso', 'exact', 'platform'),
  ('subdomain', 'oauth', 'exact', 'platform'),
  ('subdomain', 'id', 'exact', 'platform'),
  ('subdomain', 'identity', 'exact', 'platform'),
  ('subdomain', 'verify', 'exact', 'platform'),
  ('subdomain', 'secure', 'exact', 'platform'),
  ('subdomain', 'xn--', 'prefix', 'lookalike');