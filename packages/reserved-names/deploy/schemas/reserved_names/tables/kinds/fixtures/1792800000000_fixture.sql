-- Deploy schemas/reserved_names/tables/kinds/fixtures/1792800000000_fixture to pg

-- requires: schemas/reserved_names/schema
-- requires: schemas/reserved_names/tables/kinds/table

BEGIN;

INSERT INTO reserved_names.kinds (kind, description) VALUES
  ('subdomain', 'A label under a shared domain, like login in login.example.com'),
  ('username', 'A person''s handle'),
  ('domain', 'A whole domain name, like example.com'),
  ('slug', 'A name in a URL path, like an organization or app slug');

COMMIT;
