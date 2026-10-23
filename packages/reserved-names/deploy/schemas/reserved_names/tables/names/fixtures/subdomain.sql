-- Deploy schemas/reserved_names/tables/names/fixtures/subdomain to pg

-- requires: schemas/reserved_names/schema
-- requires: schemas/reserved_names/tables/names/table

BEGIN;

-- Labels a visitor would read as the platform's own when they sit under a
-- shared domain (login.<domain>, admin.<domain>, ...).
INSERT INTO reserved_names.names (kind, name, reason)
SELECT 'subdomain', label, 'platform'
  FROM unnest(ARRAY[
    'www', 'api', 'auth', 'login', 'logout', 'signin', 'signup', 'register',
    'admin', 'administrator', 'root', 'app', 'apps', 'dashboard', 'console',
    'account', 'accounts', 'billing', 'pay', 'payments', 'checkout', 'support',
    'help', 'status', 'docs', 'mail', 'email', 'smtp', 'imap', 'ftp', 'ns',
    'ns1', 'ns2', 'mx', 'cdn', 'static', 'assets', 'files', 'storage', 'media',
    'ws', 'wss', 'graphql', 'modules', 'agent', 'compute', 'machines', 'cluster',
    'migrate', 'internal', 'system', 'platform', 'security', 'sso', 'oauth', 'id',
    'identity', 'verify', 'secure'
  ]) AS label;

-- Punycode: lookalike-letter labels (a Cyrillic "а" in "аpple") all start xn--.
INSERT INTO reserved_names.names (kind, name, is_prefix, reason)
VALUES ('subdomain', 'xn--', true, 'punycode lookalikes');

COMMIT;
