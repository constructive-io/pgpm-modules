-- Deploy schemas/reserved_names/tables/reasons/fixtures/1792800000001_fixture to pg

-- requires: schemas/reserved_names/schema
-- requires: schemas/reserved_names/tables/reasons/table

BEGIN;

INSERT INTO reserved_names.reasons (reason, description) VALUES
  ('platform', 'Reads as the platform''s own (login, admin, status, ...)'),
  ('brand', 'Our brand or product names'),
  ('lookalike', 'Can be made to look like another name, e.g. punycode'),
  ('abuse', 'Offensive or used for abuse');

COMMIT;
