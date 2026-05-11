\echo Use "CREATE EXTENSION metaschema-schema" to load this file. \quit
CREATE SCHEMA metaschema_private;

GRANT USAGE ON SCHEMA metaschema_private TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA metaschema_private
  GRANT ALL ON TABLES TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA metaschema_private
  GRANT ALL ON SEQUENCES TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA metaschema_private
  GRANT ALL ON FUNCTIONS TO authenticated;

CREATE SCHEMA metaschema_public;

GRANT USAGE ON SCHEMA metaschema_public TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA metaschema_public
  GRANT ALL ON TABLES TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA metaschema_public
  GRANT ALL ON SEQUENCES TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA metaschema_public
  GRANT ALL ON FUNCTIONS TO authenticated;

CREATE TYPE metaschema_public.object_category AS ENUM ('core', 'module', 'app');

CREATE TABLE metaschema_public.database (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  owner_id uuid,
  schema_hash text,
  name text,
  label text,
  hash uuid,
  UNIQUE (schema_hash)
);

ALTER TABLE metaschema_public.database 
  ADD CONSTRAINT db_namechk 
    CHECK (char_length(name) > 2);

COMMENT ON COLUMN metaschema_public.database.schema_hash IS '@omit';

CREATE TABLE metaschema_public.schema (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  database_id uuid NOT NULL,
  name text NOT NULL,
  schema_name text NOT NULL,
  label text,
  description text,
  smart_tags jsonb,
  category metaschema_public.object_category NOT NULL DEFAULT 'app',
  module text NULL,
  scope int NULL,
  tags citext[] NOT NULL DEFAULT '{}',
  is_public boolean NOT NULL DEFAULT true,
  CONSTRAINT db_fkey
    FOREIGN KEY(database_id)
    REFERENCES metaschema_public.database (id)
    ON DELETE CASCADE,
  UNIQUE (database_id, name),
  UNIQUE (schema_name)
);

ALTER TABLE metaschema_public.schema 
  ADD CONSTRAINT schema_namechk 
    CHECK (char_length(name) > 2);

CREATE INDEX schema_database_id_idx ON metaschema_public.schema (database_id);

CREATE TABLE metaschema_public."table" (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  database_id uuid NOT NULL DEFAULT uuid_nil(),
  schema_id uuid NOT NULL,
  name text NOT NULL,
  label text,
  description text,
  smart_tags jsonb,
  category metaschema_public.object_category NOT NULL DEFAULT 'app',
  module text NULL,
  scope int NULL,
  use_rls boolean NOT NULL DEFAULT false,
  timestamps boolean NOT NULL DEFAULT false,
  peoplestamps boolean NOT NULL DEFAULT false,
  plural_name text,
  singular_name text,
  tags citext[] NOT NULL DEFAULT '{}',
  CONSTRAINT db_fkey
    FOREIGN KEY(database_id)
    REFERENCES metaschema_public.database (id)
    ON DELETE CASCADE,
  CONSTRAINT schema_fkey
    FOREIGN KEY(schema_id)
    REFERENCES metaschema_public.schema (id)
    ON DELETE CASCADE,
  UNIQUE (database_id, schema_id, name)
);

ALTER TABLE metaschema_public."table" 
  ADD COLUMN inherits_id uuid
    NULL
    REFERENCES metaschema_public."table" (id);

CREATE INDEX table_schema_id_idx ON metaschema_public."table" (schema_id);

CREATE INDEX table_database_id_idx ON metaschema_public."table" (database_id);

CREATE TABLE metaschema_public.check_constraint (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  database_id uuid NOT NULL DEFAULT uuid_nil(),
  table_id uuid NOT NULL,
  name text,
  type text,
  field_ids uuid[] NOT NULL,
  expr jsonb,
  smart_tags jsonb,
  category metaschema_public.object_category NOT NULL DEFAULT 'app',
  module text NULL,
  scope int NULL,
  tags citext[] NOT NULL DEFAULT '{}',
  CONSTRAINT db_fkey
    FOREIGN KEY(database_id)
    REFERENCES metaschema_public.database (id)
    ON DELETE CASCADE,
  CONSTRAINT table_fkey
    FOREIGN KEY(table_id)
    REFERENCES metaschema_public."table" (id)
    ON DELETE CASCADE,
  UNIQUE (table_id, name),
  CHECK (field_ids <> '{}')
);

CREATE INDEX check_constraint_table_id_idx ON metaschema_public.check_constraint (table_id);

CREATE INDEX check_constraint_database_id_idx ON metaschema_public.check_constraint (database_id);

CREATE FUNCTION metaschema_private.database_name_hash(name text) RETURNS bytea AS $EOFCODE$
  SELECT
    DECODE(MD5(LOWER(inflection.plural (name))), 'hex');
$EOFCODE$ LANGUAGE sql IMMUTABLE;

CREATE UNIQUE INDEX databases_database_unique_name_idx ON metaschema_public.database (owner_id, (metaschema_private.database_name_hash(name)));

CREATE TABLE metaschema_public.field (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  database_id uuid NOT NULL DEFAULT uuid_nil(),
  table_id uuid NOT NULL,
  name text NOT NULL,
  label text,
  description text,
  smart_tags jsonb,
  is_required boolean NOT NULL DEFAULT false,
  api_required boolean NOT NULL DEFAULT false,
  default_value text NULL DEFAULT NULL,
  default_value_ast jsonb NULL DEFAULT NULL,
  type citext NOT NULL,
  field_order int NOT NULL DEFAULT 0,
  regexp text DEFAULT NULL,
  chk jsonb DEFAULT NULL,
  chk_expr jsonb DEFAULT NULL,
  min double precision DEFAULT NULL,
  max double precision DEFAULT NULL,
  tags citext[] NOT NULL DEFAULT '{}',
  category metaschema_public.object_category NOT NULL DEFAULT 'app',
  module text NULL,
  scope int NULL,
  CONSTRAINT db_fkey
    FOREIGN KEY(database_id)
    REFERENCES metaschema_public.database (id)
    ON DELETE CASCADE,
  CONSTRAINT table_fkey
    FOREIGN KEY(table_id)
    REFERENCES metaschema_public."table" (id)
    ON DELETE CASCADE,
  UNIQUE (table_id, name)
);

CREATE INDEX field_table_id_idx ON metaschema_public.field (table_id);

CREATE INDEX field_database_id_idx ON metaschema_public.field (database_id);

COMMENT ON COLUMN metaschema_public.field.default_value IS '@sqlExpression';

CREATE UNIQUE INDEX databases_field_uniq_names_idx ON metaschema_public.field (table_id, (decode(md5(lower(CASE 
  WHEN type = 'uuid' THEN regexp_replace(name, '^(.+?)(_row_id|_id|_uuid|_fk|_pk)$', E'\\1', 'i') 
  ELSE name 
END)), 'hex')));

CREATE TABLE metaschema_public.foreign_key_constraint (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  database_id uuid NOT NULL DEFAULT uuid_nil(),
  table_id uuid NOT NULL,
  name text,
  description text,
  smart_tags jsonb,
  type text,
  field_ids uuid[] NOT NULL,
  ref_table_id uuid NOT NULL REFERENCES metaschema_public."table" (id)
    ON DELETE CASCADE,
  ref_field_ids uuid[] NOT NULL,
  delete_action char(1) DEFAULT 'c',
  update_action char(1) DEFAULT 'a',
  category metaschema_public.object_category NOT NULL DEFAULT 'app',
  module text NULL,
  scope int NULL,
  tags citext[] NOT NULL DEFAULT '{}',
  CONSTRAINT db_fkey
    FOREIGN KEY(database_id)
    REFERENCES metaschema_public.database (id)
    ON DELETE CASCADE,
  CONSTRAINT table_fkey
    FOREIGN KEY(table_id)
    REFERENCES metaschema_public."table" (id)
    ON DELETE CASCADE,
  UNIQUE (table_id, name),
  CHECK (field_ids <> '{}'),
  CHECK (ref_field_ids <> '{}')
);

CREATE INDEX foreign_key_constraint_table_id_idx ON metaschema_public.foreign_key_constraint (table_id);

CREATE INDEX foreign_key_constraint_database_id_idx ON metaschema_public.foreign_key_constraint (database_id);

CREATE TABLE metaschema_public.full_text_search (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  database_id uuid NOT NULL DEFAULT uuid_nil(),
  table_id uuid NOT NULL,
  field_id uuid NOT NULL,
  field_ids uuid[] NOT NULL,
  weights text[] NOT NULL,
  langs text[] NOT NULL,
  CONSTRAINT db_fkey
    FOREIGN KEY(database_id)
    REFERENCES metaschema_public.database (id)
    ON DELETE CASCADE,
  CONSTRAINT table_fkey
    FOREIGN KEY(table_id)
    REFERENCES metaschema_public."table" (id)
    ON DELETE CASCADE,
  CHECK (
    cardinality(field_ids) = cardinality(weights)
      AND cardinality(weights) = cardinality(langs)
  )
);

CREATE INDEX full_text_search_table_id_idx ON metaschema_public.full_text_search (table_id);

CREATE INDEX full_text_search_database_id_idx ON metaschema_public.full_text_search (database_id);

CREATE TABLE metaschema_public.index (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  database_id uuid NOT NULL,
  table_id uuid NOT NULL,
  name text NOT NULL DEFAULT '',
  field_ids uuid[],
  include_field_ids uuid[],
  access_method text NOT NULL DEFAULT 'BTREE',
  index_params jsonb,
  where_clause jsonb,
  is_unique boolean NOT NULL DEFAULT false,
  options jsonb,
  op_classes text[],
  smart_tags jsonb,
  category metaschema_public.object_category NOT NULL DEFAULT 'app',
  module text NULL,
  scope int NULL,
  tags citext[] NOT NULL DEFAULT '{}',
  CONSTRAINT db_fkey
    FOREIGN KEY(database_id)
    REFERENCES metaschema_public.database (id)
    ON DELETE CASCADE,
  CONSTRAINT table_fkey
    FOREIGN KEY(table_id)
    REFERENCES metaschema_public."table" (id)
    ON DELETE CASCADE,
  UNIQUE (database_id, name)
);

CREATE INDEX index_table_id_idx ON metaschema_public.index (table_id);

CREATE INDEX index_database_id_idx ON metaschema_public.index (database_id);

CREATE TABLE metaschema_public.policy (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  database_id uuid NOT NULL DEFAULT uuid_nil(),
  table_id uuid NOT NULL,
  name text,
  grantee_name text,
  privilege text,
  permissive boolean DEFAULT true,
  disabled boolean DEFAULT false,
  policy_type text,
  data jsonb,
  smart_tags jsonb,
  category metaschema_public.object_category NOT NULL DEFAULT 'app',
  module text NULL,
  scope int NULL,
  tags citext[] NOT NULL DEFAULT '{}',
  CONSTRAINT db_fkey
    FOREIGN KEY(database_id)
    REFERENCES metaschema_public.database (id)
    ON DELETE CASCADE,
  CONSTRAINT table_fkey
    FOREIGN KEY(table_id)
    REFERENCES metaschema_public."table" (id)
    ON DELETE CASCADE,
  UNIQUE (table_id, name)
);

CREATE INDEX policy_table_id_idx ON metaschema_public.policy (table_id);

CREATE INDEX policy_database_id_idx ON metaschema_public.policy (database_id);

CREATE TABLE metaschema_public.primary_key_constraint (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  database_id uuid NOT NULL DEFAULT uuid_nil(),
  table_id uuid NOT NULL,
  name text,
  type text,
  field_ids uuid[] NOT NULL,
  smart_tags jsonb,
  category metaschema_public.object_category NOT NULL DEFAULT 'app',
  module text NULL,
  scope int NULL,
  tags citext[] NOT NULL DEFAULT '{}',
  CONSTRAINT db_fkey
    FOREIGN KEY(database_id)
    REFERENCES metaschema_public.database (id)
    ON DELETE CASCADE,
  CONSTRAINT table_fkey
    FOREIGN KEY(table_id)
    REFERENCES metaschema_public."table" (id)
    ON DELETE CASCADE,
  UNIQUE (table_id, name),
  CHECK (field_ids <> '{}')
);

CREATE INDEX primary_key_constraint_table_id_idx ON metaschema_public.primary_key_constraint (table_id);

CREATE INDEX primary_key_constraint_database_id_idx ON metaschema_public.primary_key_constraint (database_id);

CREATE TABLE metaschema_public.schema_grant (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  database_id uuid NOT NULL DEFAULT uuid_nil(),
  schema_id uuid NOT NULL,
  grantee_name text NOT NULL,
  CONSTRAINT db_fkey
    FOREIGN KEY(database_id)
    REFERENCES metaschema_public.database (id)
    ON DELETE CASCADE,
  CONSTRAINT schema_fkey
    FOREIGN KEY(schema_id)
    REFERENCES metaschema_public.schema (id)
    ON DELETE CASCADE
);

CREATE INDEX schema_grant_schema_id_idx ON metaschema_public.schema_grant (schema_id);

CREATE INDEX schema_grant_database_id_idx ON metaschema_public.schema_grant (database_id);

CREATE TABLE metaschema_public.table_grant (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  database_id uuid NOT NULL DEFAULT uuid_nil(),
  table_id uuid NOT NULL,
  privilege text NOT NULL,
  grantee_name text NOT NULL,
  field_ids uuid[],
  is_grant boolean NOT NULL DEFAULT true,
  CONSTRAINT db_fkey
    FOREIGN KEY(database_id)
    REFERENCES metaschema_public.database (id)
    ON DELETE CASCADE,
  CONSTRAINT table_fkey
    FOREIGN KEY(table_id)
    REFERENCES metaschema_public."table" (id)
    ON DELETE CASCADE
);

CREATE INDEX table_grant_table_id_idx ON metaschema_public.table_grant (table_id);

CREATE INDEX table_grant_database_id_idx ON metaschema_public.table_grant (database_id);

CREATE FUNCTION metaschema_private.table_name_hash(name text) RETURNS bytea AS $EOFCODE$
  SELECT
    DECODE(MD5(LOWER(inflection.plural (name))), 'hex');
$EOFCODE$ LANGUAGE sql IMMUTABLE;

CREATE UNIQUE INDEX databases_table_unique_name_idx ON metaschema_public."table" (database_id, schema_id, (metaschema_private.table_name_hash(name)));

CREATE TABLE metaschema_public.trigger_function (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  database_id uuid NOT NULL,
  name text NOT NULL,
  code text,
  CONSTRAINT db_fkey
    FOREIGN KEY(database_id)
    REFERENCES metaschema_public.database (id)
    ON DELETE CASCADE,
  UNIQUE (database_id, name)
);

CREATE INDEX trigger_function_database_id_idx ON metaschema_public.trigger_function (database_id);

CREATE TABLE metaschema_public.trigger (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  database_id uuid NOT NULL DEFAULT uuid_nil(),
  table_id uuid NOT NULL,
  name text NOT NULL,
  event text,
  function_name text,
  smart_tags jsonb,
  category metaschema_public.object_category NOT NULL DEFAULT 'app',
  module text NULL,
  scope int NULL,
  tags citext[] NOT NULL DEFAULT '{}',
  CONSTRAINT db_fkey
    FOREIGN KEY(database_id)
    REFERENCES metaschema_public.database (id)
    ON DELETE CASCADE,
  CONSTRAINT table_fkey
    FOREIGN KEY(table_id)
    REFERENCES metaschema_public."table" (id)
    ON DELETE CASCADE,
  UNIQUE (table_id, name)
);

CREATE INDEX trigger_table_id_idx ON metaschema_public.trigger (table_id);

CREATE INDEX trigger_database_id_idx ON metaschema_public.trigger (database_id);

CREATE TABLE metaschema_public.unique_constraint (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  database_id uuid NOT NULL DEFAULT uuid_nil(),
  table_id uuid NOT NULL,
  name text,
  description text,
  smart_tags jsonb,
  type text,
  field_ids uuid[] NOT NULL,
  category metaschema_public.object_category NOT NULL DEFAULT 'app',
  module text NULL,
  scope int NULL,
  tags citext[] NOT NULL DEFAULT '{}',
  CONSTRAINT db_fkey
    FOREIGN KEY(database_id)
    REFERENCES metaschema_public.database (id)
    ON DELETE CASCADE,
  CONSTRAINT table_fkey
    FOREIGN KEY(table_id)
    REFERENCES metaschema_public."table" (id)
    ON DELETE CASCADE,
  UNIQUE (table_id, name),
  CHECK (field_ids <> '{}')
);

CREATE INDEX unique_constraint_table_id_idx ON metaschema_public.unique_constraint (table_id);

CREATE INDEX unique_constraint_database_id_idx ON metaschema_public.unique_constraint (database_id);

CREATE TABLE metaschema_public.view (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  database_id uuid NOT NULL DEFAULT uuid_nil(),
  schema_id uuid NOT NULL,
  name text NOT NULL,
  table_id uuid,
  view_type text NOT NULL,
  data jsonb DEFAULT '{}',
  filter_type text,
  filter_data jsonb DEFAULT '{}',
  security_invoker boolean DEFAULT true,
  is_read_only boolean DEFAULT true,
  smart_tags jsonb,
  category metaschema_public.object_category NOT NULL DEFAULT 'app',
  module text NULL,
  scope int NULL,
  tags citext[] NOT NULL DEFAULT '{}',
  CONSTRAINT db_fkey
    FOREIGN KEY(database_id)
    REFERENCES metaschema_public.database (id)
    ON DELETE CASCADE,
  CONSTRAINT schema_fkey
    FOREIGN KEY(schema_id)
    REFERENCES metaschema_public.schema (id)
    ON DELETE CASCADE,
  CONSTRAINT table_fkey
    FOREIGN KEY(table_id)
    REFERENCES metaschema_public."table" (id)
    ON DELETE CASCADE,
  UNIQUE (schema_id, name)
);

CREATE INDEX view_schema_id_idx ON metaschema_public.view (schema_id);

CREATE INDEX view_database_id_idx ON metaschema_public.view (database_id);

CREATE INDEX view_table_id_idx ON metaschema_public.view (table_id);

CREATE TABLE metaschema_public.view_table (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  view_id uuid NOT NULL,
  table_id uuid NOT NULL,
  join_order int NOT NULL DEFAULT 0,
  CONSTRAINT view_fkey
    FOREIGN KEY(view_id)
    REFERENCES metaschema_public.view (id)
    ON DELETE CASCADE,
  CONSTRAINT table_fkey
    FOREIGN KEY(table_id)
    REFERENCES metaschema_public."table" (id)
    ON DELETE CASCADE,
  UNIQUE (view_id, table_id)
);

COMMENT ON TABLE metaschema_public.view_table IS 'Junction table linking views to their joined tables for referential integrity';

CREATE INDEX view_table_view_id_idx ON metaschema_public.view_table (view_id);

CREATE INDEX view_table_table_id_idx ON metaschema_public.view_table (table_id);

CREATE TABLE metaschema_public.view_grant (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  database_id uuid NOT NULL DEFAULT uuid_nil(),
  view_id uuid NOT NULL,
  grantee_name text NOT NULL,
  privilege text NOT NULL,
  with_grant_option boolean DEFAULT false,
  is_grant boolean NOT NULL DEFAULT true,
  CONSTRAINT db_fkey
    FOREIGN KEY(database_id)
    REFERENCES metaschema_public.database (id)
    ON DELETE CASCADE,
  CONSTRAINT view_fkey
    FOREIGN KEY(view_id)
    REFERENCES metaschema_public.view (id)
    ON DELETE CASCADE,
  UNIQUE (view_id, grantee_name, privilege, is_grant)
);

CREATE INDEX view_grant_view_id_idx ON metaschema_public.view_grant (view_id);

CREATE INDEX view_grant_database_id_idx ON metaschema_public.view_grant (database_id);

CREATE TABLE metaschema_public.view_rule (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  database_id uuid NOT NULL DEFAULT uuid_nil(),
  view_id uuid NOT NULL,
  name text NOT NULL,
  event text NOT NULL,
  action text NOT NULL DEFAULT 'NOTHING',
  CONSTRAINT db_fkey
    FOREIGN KEY(database_id)
    REFERENCES metaschema_public.database (id)
    ON DELETE CASCADE,
  CONSTRAINT view_fkey
    FOREIGN KEY(view_id)
    REFERENCES metaschema_public.view (id)
    ON DELETE CASCADE,
  UNIQUE (view_id, name)
);

COMMENT ON TABLE metaschema_public.view_rule IS 'DO INSTEAD rules for views (e.g., read-only enforcement)';

COMMENT ON COLUMN metaschema_public.view_rule.event IS 'INSERT, UPDATE, or DELETE';

COMMENT ON COLUMN metaschema_public.view_rule.action IS 'NOTHING (for read-only) or custom action';

CREATE INDEX view_rule_view_id_idx ON metaschema_public.view_rule (view_id);

CREATE INDEX view_rule_database_id_idx ON metaschema_public.view_rule (database_id);

CREATE TABLE metaschema_public.default_privilege (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  database_id uuid NOT NULL DEFAULT uuid_nil(),
  schema_id uuid NOT NULL,
  object_type text NOT NULL,
  privilege text NOT NULL,
  grantee_name text NOT NULL,
  is_grant boolean NOT NULL DEFAULT true,
  CONSTRAINT db_fkey
    FOREIGN KEY(database_id)
    REFERENCES metaschema_public.database (id)
    ON DELETE CASCADE,
  CONSTRAINT schema_fkey
    FOREIGN KEY(schema_id)
    REFERENCES metaschema_public.schema (id)
    ON DELETE CASCADE,
  UNIQUE (schema_id, object_type, privilege, grantee_name, is_grant)
);

CREATE INDEX default_privilege_schema_id_idx ON metaschema_public.default_privilege (schema_id);

CREATE INDEX default_privilege_database_id_idx ON metaschema_public.default_privilege (database_id);

CREATE TABLE metaschema_public.enum (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  database_id uuid NOT NULL,
  schema_id uuid NOT NULL,
  name text NOT NULL,
  label text,
  description text,
  values text[] NOT NULL DEFAULT '{}',
  smart_tags jsonb,
  category metaschema_public.object_category NOT NULL DEFAULT 'app',
  module text NULL,
  scope int NULL,
  tags citext[] NOT NULL DEFAULT '{}',
  CONSTRAINT db_fkey
    FOREIGN KEY(database_id)
    REFERENCES metaschema_public.database (id)
    ON DELETE CASCADE,
  CONSTRAINT schema_fkey
    FOREIGN KEY(schema_id)
    REFERENCES metaschema_public.schema (id)
    ON DELETE CASCADE,
  UNIQUE (schema_id, name)
);

CREATE INDEX enum_schema_id_idx ON metaschema_public.enum (schema_id);

CREATE INDEX enum_database_id_idx ON metaschema_public.enum (database_id);

CREATE TABLE metaschema_public.embedding_chunks (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  database_id uuid NOT NULL DEFAULT uuid_nil(),
  table_id uuid NOT NULL,
  embedding_field_id uuid,
  chunks_table_id uuid,
  chunks_table_name text,
  content_field_name text NOT NULL DEFAULT 'content',
  dimensions int NOT NULL DEFAULT 768,
  metric text NOT NULL DEFAULT 'cosine',
  chunk_size int NOT NULL DEFAULT 1000,
  chunk_overlap int NOT NULL DEFAULT 200,
  chunk_strategy text NOT NULL DEFAULT 'fixed',
  metadata_fields jsonb,
  enqueue_chunking_job boolean NOT NULL DEFAULT true,
  chunking_task_name text NOT NULL DEFAULT 'generate_chunks',
  parent_fk_field_id uuid,
  CONSTRAINT db_fkey
    FOREIGN KEY(database_id)
    REFERENCES metaschema_public.database (id)
    ON DELETE CASCADE,
  CONSTRAINT table_fkey
    FOREIGN KEY(table_id)
    REFERENCES metaschema_public."table" (id)
    ON DELETE CASCADE,
  CONSTRAINT chunks_table_fkey
    FOREIGN KEY(chunks_table_id)
    REFERENCES metaschema_public."table" (id)
    ON DELETE SET NULL,
  CONSTRAINT embedding_field_fkey
    FOREIGN KEY(embedding_field_id)
    REFERENCES metaschema_public.field (id)
    ON DELETE SET NULL,
  CONSTRAINT parent_fk_field_fkey
    FOREIGN KEY(parent_fk_field_id)
    REFERENCES metaschema_public.field (id)
    ON DELETE SET NULL,
  CONSTRAINT valid_metric 
    CHECK (metric IN ('cosine', 'l2', 'ip')),
  CONSTRAINT valid_chunk_strategy 
    CHECK (chunk_strategy IN ('fixed', 'sentence', 'paragraph', 'semantic')),
  CONSTRAINT valid_dimensions 
    CHECK (dimensions > 0),
  CONSTRAINT valid_chunk_size 
    CHECK (chunk_size > 0),
  CONSTRAINT valid_chunk_overlap 
    CHECK (
    chunk_overlap >= 0
      AND chunk_overlap < chunk_size
  )
);

CREATE INDEX embedding_chunks_table_id_idx ON metaschema_public.embedding_chunks (table_id);

CREATE INDEX embedding_chunks_database_id_idx ON metaschema_public.embedding_chunks (database_id);

CREATE INDEX embedding_chunks_chunks_table_id_idx ON metaschema_public.embedding_chunks (chunks_table_id);

CREATE TABLE metaschema_public.spatial_relation (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  database_id uuid NOT NULL DEFAULT uuid_nil(),
  table_id uuid NOT NULL,
  field_id uuid NOT NULL,
  ref_table_id uuid NOT NULL,
  ref_field_id uuid NOT NULL,
  name text NOT NULL,
  operator text NOT NULL,
  param_name text NULL,
  category metaschema_public.object_category NOT NULL DEFAULT 'app',
  module text NULL,
  scope int NULL,
  tags citext[] NOT NULL DEFAULT '{}',
  CONSTRAINT db_fkey
    FOREIGN KEY(database_id)
    REFERENCES metaschema_public.database (id)
    ON DELETE CASCADE,
  CONSTRAINT table_fkey
    FOREIGN KEY(table_id)
    REFERENCES metaschema_public."table" (id)
    ON DELETE CASCADE,
  CONSTRAINT field_fkey
    FOREIGN KEY(field_id)
    REFERENCES metaschema_public.field (id)
    ON DELETE CASCADE,
  CONSTRAINT ref_table_fkey
    FOREIGN KEY(ref_table_id)
    REFERENCES metaschema_public."table" (id)
    ON DELETE CASCADE,
  CONSTRAINT ref_field_fkey
    FOREIGN KEY(ref_field_id)
    REFERENCES metaschema_public.field (id)
    ON DELETE CASCADE,
  UNIQUE (table_id, name),
  CHECK (operator IN ('st_contains', 'st_within', 'st_covers', 'st_coveredby', 'st_intersects', 'st_equals', 'st_bbox_intersects', 'st_dwithin')),
  CHECK (
    (operator = 'st_dwithin'
      AND param_name IS NOT NULL)
      OR (operator <> 'st_dwithin'
      AND param_name IS NULL)
  )
);

CREATE INDEX spatial_relation_table_id_idx ON metaschema_public.spatial_relation (table_id);

CREATE INDEX spatial_relation_field_id_idx ON metaschema_public.spatial_relation (field_id);

CREATE INDEX spatial_relation_database_id_idx ON metaschema_public.spatial_relation (database_id);

CREATE INDEX spatial_relation_ref_table_id_idx ON metaschema_public.spatial_relation (ref_table_id);

CREATE INDEX spatial_relation_ref_field_id_idx ON metaschema_public.spatial_relation (ref_field_id);

CREATE TABLE metaschema_public.node_type_registry (
  name text PRIMARY KEY,
  slug text NOT NULL UNIQUE,
  category text NOT NULL,
  display_name text,
  description text,
  parameter_schema jsonb NOT NULL DEFAULT '{}'::jsonb,
  tags text[] NOT NULL DEFAULT CAST('{}' AS text[])
);

CREATE INDEX node_type_registry_category_idx ON metaschema_public.node_type_registry (category);

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('AuthzAllowAll', 'authz_allow_all', 'authz', 'Public Access', 'Allows all access. Generates TRUE expression.', '{"type":"object","properties":{}}'::jsonb, CAST('{"authz"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('AuthzAppMembership', 'authz_app_membership_check', 'authz', 'App Membership Check', 'App-level membership check (hardcoded membership_type=1). Verifies the user has app membership (optionally with specific permission) without binding to any entity from the row. Uses EXISTS subquery against SPRT table. For entity-scoped checks (org, channel, etc.), use AuthzEntityMembership instead.', CAST('{"type":"object","properties":{"permission":{"type":"string","description":"Single permission name to check (resolved to bitstring mask)"},"permissions":{"type":"array","items":{"type":"string"},"description":"Multiple permission names to check (ORed together into mask)"},"is_admin":{"type":"boolean","description":"If true, require is_admin flag"},"is_owner":{"type":"boolean","description":"If true, require is_owner flag"}},"required":[]}' AS jsonb), CAST('{"membership","authz"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('AuthzComposite', 'authz_composite', 'authz', 'Composite Policy', 'Composite authorization policy that combines multiple authorization nodes using boolean logic (AND/OR). The data field contains a JSONB AST with nested authorization nodes.', '{"type":"object","description":"A composite policy containing nested authorization nodes combined with boolean logic","properties":{"BoolExpr":{"type":"object","description":"Boolean expression combining multiple authorization nodes","properties":{"boolop":{"type":"string","enum":["AND_EXPR","OR_EXPR","NOT_EXPR"],"description":"Boolean operator: AND_EXPR, OR_EXPR, or NOT_EXPR"},"args":{"type":"array","description":"Array of authorization nodes to combine","items":{"type":"object"}}}}}}'::jsonb, CAST('{"composite","authz"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('AuthzDenyAll', 'authz_deny_all', 'authz', 'No Access', 'Denies all access. Generates FALSE expression.', '{"type":"object","properties":{}}'::jsonb, CAST('{"authz"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('AuthzDirectOwner', 'authz_direct_owner', 'authz', 'Direct Ownership', 'Direct equality comparison between a table column and the current user ID. Simplest authorization pattern with no subqueries.', CAST('{"type":"object","properties":{"entity_field":{"type":"string","format":"column-ref","description":"Column name containing the owner user ID (e.g., owner_id)"}},"required":["entity_field"]}' AS jsonb), CAST('{"ownership","authz"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('AuthzDirectOwnerAny', 'authz_direct_owner_any', 'authz', 'Multi-Owner Access', 'OR logic for multiple ownership fields. Checks if current user matches any of the specified fields.', '{"type":"object","properties":{"entity_fields":{"type":"array","items":{"type":"string","format":"column-ref"},"description":"Array of column names to check for ownership"}},"required":["entity_fields"]}'::jsonb, CAST('{"ownership","authz"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('AuthzEntityMembership', 'authz_entity_membership', 'authz', 'Entity Membership', 'Membership check scoped by a field on the row through the SPRT table. Verifies user has membership in the entity referenced by the row.', CAST('{"type":"object","properties":{"entity_field":{"type":"string","format":"column-ref","description":"Column name referencing the entity (e.g., entity_id, org_id)"},"sel_field":{"type":"string","description":"SPRT column to select for the entity match","default":"entity_id"},"membership_type":{"type":["integer","string"],"description":"Scope: 1=app, 2=org, 3+=dynamic entity types (or string name resolved via membership_types_module)"},"entity_type":{"type":"string","description":"Entity type prefix (e.g. ''channel'', ''department''). Resolved to membership_type integer via memberships_module lookup. Use instead of membership_type for readability."},"permission":{"type":"string","description":"Single permission name to check (resolved to bitstring mask)"},"permissions":{"type":"array","items":{"type":"string"},"description":"Multiple permission names to check (ORed together into mask)"},"is_admin":{"type":"boolean","description":"If true, require is_admin flag"},"is_owner":{"type":"boolean","description":"If true, require is_owner flag"}},"required":["entity_field"]}' AS jsonb), CAST('{"membership","authz"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('AuthzFilePath', 'authz_file_path', 'authz', 'File Path Share', 'Path-scoped file sharing via ltree containment. Grants access when a path_shares row matches the current user, bucket, and an ancestor path with the required permission.', CAST('{"type":"object","properties":{"shares_schema":{"type":"string","description":"Schema of the path_shares table"},"shares_table":{"type":"string","description":"Name of the path_shares table"},"files_schema":{"type":"string","description":"Schema of the files table (used to qualify column references inside the EXISTS subquery)"},"files_table":{"type":"string","description":"Name of the files table (used to qualify column references inside the EXISTS subquery)"},"permission_field":{"type":"string","format":"column-ref","description":"Boolean column on the path_shares table that grants the required permission (e.g. can_read, can_write)"},"bucket_field":{"type":"string","format":"column-ref","description":"Column on the files table referencing the bucket","default":"bucket_id"},"path_field":{"type":"string","format":"column-ref","description":"Ltree column on the files table representing the file path","default":"path"}},"required":["shares_schema","shares_table","files_table","permission_field"]}' AS jsonb), CAST('{"storage","authz"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('AuthzMemberList', 'authz_member_list', 'authz', 'Member List', 'Check if current user is in an array column on the same row.', '{"type":"object","properties":{"array_field":{"type":"string","format":"column-ref","description":"Column name containing the array of user IDs"}},"required":["array_field"]}'::jsonb, CAST('{"ownership","authz"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('AuthzNotReadOnly', 'authz_not_read_only', 'authz', 'Not Read-Only', 'Restrictive policy that blocks read-only members from mutations. Checks actor_id + is_read_only IS NOT TRUE on the SPRT. Designed to run as a restrictive counterpart after a permissive AuthzEntityMembership policy has already verified membership.', CAST('{"type":"object","properties":{"entity_field":{"type":"string","format":"column-ref","description":"Column name referencing the entity (e.g., entity_id, org_id)"},"membership_type":{"type":["integer","string"],"description":"Scope: 2=org, 3+=dynamic entity types. Must be >= 2 (entity-scoped)."}},"required":["entity_field"]}' AS jsonb), CAST('{"membership","authz","restrictive"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('AuthzOrgHierarchy', 'authz_org_hierarchy', 'authz', 'Org Hierarchy', 'Organizational hierarchy visibility using closure table. Managers can see subordinate data or subordinates can see manager data.', CAST('{"type":"object","properties":{"direction":{"type":"string","enum":["up","down"],"description":"down=manager sees subordinates, up=subordinate sees managers"},"entity_field":{"type":"string","format":"column-ref","description":"Field referencing the org entity","default":"entity_id"},"anchor_field":{"type":"string","format":"column-ref","description":"Field referencing the user (e.g., owner_id)"},"max_depth":{"type":"integer","description":"Optional max depth to limit visibility"}},"required":["direction","anchor_field"]}' AS jsonb), CAST('{"membership","hierarchy","authz"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('AuthzPeerOwnership', 'authz_peer_ownership', 'authz', 'Peer Ownership', 'Peer visibility through shared entity membership. Authorizes access to user-owned rows when the owner and current user are both members of the same entity. Self-joins the SPRT table to find peers.', CAST('{"type":"object","properties":{"owner_field":{"type":"string","format":"column-ref","description":"Column name on protected table referencing the owning user (e.g., owner_id)"},"membership_type":{"type":["integer","string"],"description":"Scope: 1=app, 2=org, 3+=dynamic entity types (or string name resolved via membership_types_module)"},"entity_type":{"type":"string","description":"Entity type prefix (e.g. ''channel'', ''department''). Resolved to membership_type integer via memberships_module lookup. Use instead of membership_type for readability."},"permission":{"type":"string","description":"Single permission name to check on the current user membership (resolved to bitstring mask)"},"permissions":{"type":"array","items":{"type":"string"},"description":"Multiple permission names to check on the current user membership (ORed together into mask)"},"is_admin":{"type":"boolean","description":"If true, require is_admin flag on current user membership"},"is_owner":{"type":"boolean","description":"If true, require is_owner flag on current user membership"}},"required":["owner_field"]}' AS jsonb), CAST('{"membership","peer","authz"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('AuthzPublishable', 'authz_publishable', 'authz', 'Published Content', 'Published state access control. Restricts access to records that are published.', CAST('{"type":"object","properties":{"is_published_field":{"type":"string","format":"column-ref","description":"Boolean field indicating published state","default":"is_published"},"published_at_field":{"type":"string","format":"column-ref","description":"Timestamp field for publish time","default":"published_at"},"require_published_at":{"type":"boolean","description":"Require published_at to be non-null and <= now()","default":true}}}' AS jsonb), CAST('{"temporal","publishing","authz"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('AuthzRelatedEntityMembership', 'authz_related_entity_membership', 'authz', 'Related Entity Membership', 'JOIN-based membership verification through related tables. Joins SPRT table with another table to verify membership.', CAST('{"type":"object","properties":{"entity_field":{"type":"string","format":"column-ref","description":"Column name on protected table referencing the join table"},"sel_field":{"type":"string","description":"SPRT column to select for the entity match","default":"entity_id"},"sprt_join_field":{"type":"string","description":"SPRT column to join on with the related table","default":"entity_id"},"membership_type":{"type":["integer","string"],"description":"Scope: 1=app, 2=org, 3+=dynamic entity types (or string name resolved via membership_types_module)"},"entity_type":{"type":"string","description":"Entity type prefix (e.g. ''channel'', ''department''). Resolved to membership_type integer via memberships_module lookup. Use instead of membership_type for readability."},"obj_table_id":{"type":"string","format":"uuid","description":"UUID of the join table (alternative to obj_schema/obj_table)"},"obj_schema":{"type":"string","description":"Schema of the join table (or use obj_table_id)"},"obj_table":{"type":"string","description":"Name of the join table (or use obj_table_id)"},"obj_field_id":{"type":"string","format":"uuid","description":"UUID of field on join table (alternative to obj_field)"},"obj_field":{"type":"string","format":"column-ref","description":"Field name on join table to match against SPRT entity_id"},"permission":{"type":"string","description":"Single permission name to check (resolved to bitstring mask)"},"permissions":{"type":"array","items":{"type":"string"},"description":"Multiple permission names to check (ORed together into mask)"},"is_admin":{"type":"boolean","description":"If true, require is_admin flag"},"is_owner":{"type":"boolean","description":"If true, require is_owner flag"}},"required":["entity_field"]}' AS jsonb), CAST('{"membership","authz"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('AuthzRelatedMemberList', 'authz_related_member_list', 'authz', 'Related Member List', 'Array membership check in a related table.', '{"type":"object","properties":{"owned_schema":{"type":"string","description":"Schema of the related table"},"owned_table":{"type":"string","description":"Name of the related table"},"owned_table_key":{"type":"string","format":"column-ref","description":"Array column in related table"},"owned_table_ref_key":{"type":"string","format":"column-ref","description":"FK column in related table"},"this_object_key":{"type":"string","format":"column-ref","description":"PK column in protected table"}},"required":["owned_schema","owned_table","owned_table_key","owned_table_ref_key","this_object_key"]}'::jsonb, CAST('{"ownership","authz"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('AuthzRelatedPeerOwnership', 'authz_related_peer_ownership', 'authz', 'Related Peer Ownership', 'Peer visibility through shared entity membership via a related table. Like AuthzPeerOwnership but the owning user is resolved through a FK JOIN to a related table. Combines SPRT self-join with object table JOIN.', CAST('{"type":"object","properties":{"entity_field":{"type":"string","format":"column-ref","description":"Column name on protected table referencing the related table (e.g., message_id)"},"membership_type":{"type":["integer","string"],"description":"Scope: 1=app, 2=org, 3+=dynamic entity types (or string name resolved via membership_types_module)"},"entity_type":{"type":"string","description":"Entity type prefix (e.g. ''channel'', ''department''). Resolved to membership_type integer via memberships_module lookup. Use instead of membership_type for readability."},"obj_table_id":{"type":"string","format":"uuid","description":"UUID of the related table (alternative to obj_schema/obj_table)"},"obj_schema":{"type":"string","description":"Schema of the related table (or use obj_table_id)"},"obj_table":{"type":"string","description":"Name of the related table (or use obj_table_id)"},"obj_field_id":{"type":"string","format":"uuid","description":"UUID of field on related table containing the owner user ID (alternative to obj_field)"},"obj_field":{"type":"string","format":"column-ref","description":"Field name on related table containing the owner user ID (e.g., sender_id)"},"obj_ref_field":{"type":"string","format":"column-ref","description":"Field on related table to select for matching entity_field","default":"id"},"permission":{"type":"string","description":"Single permission name to check on the current user membership (resolved to bitstring mask)"},"permissions":{"type":"array","items":{"type":"string"},"description":"Multiple permission names to check on the current user membership (ORed together into mask)"},"is_admin":{"type":"boolean","description":"If true, require is_admin flag on current user membership"},"is_owner":{"type":"boolean","description":"If true, require is_owner flag on current user membership"}},"required":["entity_field"]}' AS jsonb), CAST('{"membership","peer","authz"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('AuthzTemporal', 'authz_temporal', 'authz', 'Temporal Access', 'Time-window based access control. Restricts access based on valid_from and/or valid_until timestamps. At least one of valid_from_field or valid_until_field must be provided.', CAST('{"type":"object","properties":{"valid_from_field":{"type":"string","format":"column-ref","description":"Column for start time (at least one of valid_from_field or valid_until_field required)"},"valid_until_field":{"type":"string","format":"column-ref","description":"Column for end time (at least one of valid_from_field or valid_until_field required)"},"valid_from_inclusive":{"type":"boolean","description":"Include start boundary","default":true},"valid_until_inclusive":{"type":"boolean","description":"Include end boundary","default":false}},"anyOf":[{"required":["valid_from_field"]},{"required":["valid_until_field"]}]}' AS jsonb), CAST('{"temporal","authz"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('DataCompositeField', 'data_composite_field', 'data', 'Composite Field', 'Creates a derived text field that automatically concatenates multiple source fields via BEFORE INSERT/UPDATE triggers. Used to produce a unified text representation (e.g., embedding_text) from multiple columns on a table. The trigger fires with ''_000'' prefix to run before Search* triggers alphabetically.', CAST('{"type":"object","properties":{"target":{"type":"string","format":"column-ref","description":"Name of the derived text field to create (default: ''embedding_text'')"},"source_fields":{"type":"array","items":{"type":"string","format":"column-ref"},"description":"Array of source field names to concatenate into the target field"},"format":{"type":"string","enum":["labeled","plain"],"description":"Output format: ''labeled'' (field_name: value) or ''plain'' (values only). Default: ''labeled''"}},"required":["source_fields"]}' AS jsonb), CAST('{"transform","behavior"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('DataDirectOwner', 'data_direct_owner', 'data', 'Ownership', 'Adds ownership column for direct user ownership. Enables AuthzDirectOwner authorization.', '{"type":"object","properties":{"owner_field_name":{"type":"string","format":"column-ref","description":"Column name for owner ID","default":"owner_id"},"include_id":{"type":"boolean","description":"If true, also adds a UUID primary key column with auto-generation","default":true},"include_user_fk":{"type":"boolean","description":"If true, adds a foreign key constraint from owner_id to the users table","default":true}}}'::jsonb, CAST('{"ownership","schema"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('DataEntityMembership', 'data_entity_membership', 'data', 'Entity Membership', 'Adds entity reference for organization/group scoping. Enables AuthzEntityMembership, AuthzMembership, AuthzOrgHierarchy authorization.', '{"type":"object","properties":{"entity_field_name":{"type":"string","format":"column-ref","description":"Column name for entity ID","default":"entity_id"},"include_id":{"type":"boolean","description":"If true, also adds a UUID primary key column with auto-generation","default":true},"include_user_fk":{"type":"boolean","description":"If true, adds a foreign key constraint from entity_id to the users table","default":true}}}'::jsonb, CAST('{"membership","schema"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('DataFeatureFlag', 'data_feature_flag', 'data', 'Feature Flag', 'Gates a table behind a feature flag backed by the cap tables. Attaches a BEFORE INSERT trigger that checks whether the named feature cap value is > 0. Features are modeled as caps with max=0 (disabled) or max=1 (enabled) in limit_caps / limit_caps_defaults tables. Resolution: COALESCE(per-entity cap, scope default, 0).', CAST(E'{"type":"object","properties":{"feature_name":{"type":"string","description":"Cap name representing this feature (must match a limit_caps_defaults entry with max=0 or max=1)"},"scope":{"type":"string","enum":["app","org"],"description":"Feature scope: \\"app\\" (membership_type=1, app-level caps) or \\"org\\" (membership_type=2, per-entity caps)","default":"app"},"entity_field":{"type":"string","format":"column-ref","description":"Column on the target table that holds the entity id for per-entity cap lookups (only used for org scope)","default":"entity_id"}},"required":["feature_name"]}' AS jsonb), CAST('{"limits","triggers","feature-flags","billing","caps"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('DataFileEmbedding', 'data_file_embedding', 'data', 'File Embedding', 'Generic, MIME-scoped embedding node for file tables. Supports two modes: direct (whole-file to single vector, e.g. CLIP for images) when extraction is omitted, or extract (file to text to chunks to per-chunk vectors) when extraction config is provided. Composes SearchVector + DataJobTrigger internally. Multiple instances can coexist on the same table with different MIME scopes, field names, and embedding strategies.', CAST('{"type":"object","properties":{"field_name":{"type":"string","format":"column-ref","description":"Name of the vector embedding column","default":"embedding"},"dimensions":{"type":"integer","description":"Vector dimensions (e.g. 512 for CLIP, 768 for nomic, 1536 for ada-002)","default":768},"index_method":{"type":"string","enum":["hnsw","ivfflat"],"description":"Index type for similarity search","default":"hnsw"},"metric":{"type":"string","enum":["cosine","l2","ip"],"description":"Distance metric","default":"cosine"},"index_options":{"type":"object","description":"Index-specific options. HNSW: {m, ef_construction}. IVFFlat: {lists}.","default":{}},"mime_patterns":{"type":"array","items":{"type":"string"},"description":"MIME type LIKE patterns to match. Multiple patterns are OR''d together. Examples: [''image/%''], [''application/pdf'', ''text/%''], [''audio/%''].","default":["image/%"]},"task_identifier":{"type":"string","description":"Job task identifier for the worker. In direct mode this is the embedding worker; in extract mode this is the extraction worker.","default":"process_file_embedding"},"events":{"type":"array","items":{"type":"string","enum":["INSERT","UPDATE"]},"description":"Trigger events that fire the job","default":["INSERT"]},"payload_custom":{"type":"object","additionalProperties":{"type":"string","format":"column-ref"},"description":"Custom payload key-to-column mapping for the job trigger","default":{"file_id":"id","key":"key","mime_type":"mime_type","bucket_id":"bucket_id"}},"trigger_conditions":{"description":"Additional compound conditions beyond MIME filtering. Merged with the auto-generated MIME conditions via AND. Use this to add status checks, field guards, etc.","x-codegen-type":"TriggerCondition | TriggerCondition[]","oneOf":[{"$ref":"#/$defs/triggerCondition"},{"type":"array","items":{"$ref":"#/$defs/triggerCondition"}}]},"extraction":{"type":"object","description":"Text extraction configuration. When present, the generator creates extraction output fields on the table and configures SearchVector with source_fields + stale tracking. When absent, the node operates in direct mode (single vector per file, no text extraction).","properties":{"text_field":{"type":"string","format":"column-ref","description":"Field to store extracted text/markdown","default":"extracted_text"},"metadata_field":{"type":"string","format":"column-ref","description":"JSONB field for extraction metadata (page count, language, etc.)","default":"extracted_metadata"},"status_field":{"type":"string","format":"column-ref","description":"Extraction lifecycle status field","default":"extraction_status"}}},"chunks":{"type":"object","description":"Chunking configuration. Creates an embedding_chunks record that drives automatic text splitting and per-chunk embedding. Only meaningful when extraction is also provided.","properties":{"content_field_name":{"type":"string","format":"column-ref","description":"Name of the text content column in the chunks table","default":"content"},"chunk_size":{"type":"integer","description":"Maximum number of characters per chunk","default":1000},"chunk_overlap":{"type":"integer","description":"Number of overlapping characters between consecutive chunks","default":200},"chunk_strategy":{"type":"string","enum":["fixed","sentence","paragraph","semantic"],"description":"Strategy for splitting text into chunks","default":"paragraph"},"metadata_fields":{"type":"object","description":"Metadata fields from parent to copy into chunks"},"enqueue_chunking_job":{"type":"boolean","description":"Whether to auto-enqueue a chunking job on insert/update","default":true},"chunking_task_name":{"type":"string","description":"Task identifier for the chunking job queue","default":"generate_chunks"}}},"stale_strategy":{"type":"string","enum":["column","null","hash"],"description":"Strategy for tracking embedding staleness when extraction is enabled. column: embedding_stale boolean. null: set embedding to NULL. hash: md5 hash.","default":"column"},"include_stale_field":{"type":"boolean","description":"Whether to include the embedding_stale boolean field (extract mode)","default":true}}}' AS jsonb), CAST('{"embedding","vector","ai","composition","jobs","multimodal","files"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('DataForceCurrentUser', 'data_force_current_user', 'data', 'Force Current User', 'BEFORE INSERT trigger that forces a field to the value of jwt_public.current_user_id(). Prevents clients from spoofing the actor/uploader identity. The field value is always overwritten regardless of what the client provides.', CAST('{"type":"object","properties":{"field_name":{"type":"string","format":"column-ref","description":"Name of the field to force to current_user_id()","default":"actor_id"}}}' AS jsonb), CAST('{"trigger","security","schema"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('DataId', 'data_id', 'data', 'Primary Key ID', 'Adds a UUID primary key column with auto-generation default (uuidv7). This is the standard primary key pattern for all tables.', '{"type":"object","properties":{"field_name":{"type":"string","format":"column-ref","description":"Column name for the primary key","default":"id"}}}'::jsonb, CAST('{"primary_key","schema"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('DataImageEmbedding', 'data_image_embedding', 'data', 'Image Embedding', 'Composition wrapper that creates a vector embedding field with HNSW/IVFFlat index (via SearchVector) and a job trigger with compound conditions (via DataJobTrigger) that fires on INSERT for image files matching mime_type patterns. Designed for storage file tables.', CAST('{"type":"object","properties":{"field_name":{"type":"string","format":"column-ref","description":"Name of the vector embedding column","default":"embedding"},"dimensions":{"type":"integer","description":"Vector dimensions","default":512},"index_method":{"type":"string","enum":["hnsw","ivfflat"],"description":"Index type for similarity search","default":"hnsw"},"metric":{"type":"string","enum":["cosine","l2","ip"],"description":"Distance metric","default":"cosine"},"task_identifier":{"type":"string","description":"Job task identifier for the embedding worker","default":"process_image_embedding"},"mime_patterns":{"type":"array","items":{"type":"string"},"description":"MIME type LIKE patterns to match (e.g., image/%, video/%). Multiple patterns are OR''d together.","default":["image/%"]},"payload_custom":{"type":"object","additionalProperties":{"type":"string","format":"column-ref"},"description":"Custom payload key-to-column mapping for the job trigger","default":{"file_id":"id","key":"key","mime_type":"mime_type","bucket_id":"bucket_id"}}}}' AS jsonb), CAST('{"embedding","image","vector","ai","composition","jobs"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('DataImmutableFields', 'data_immutable_fields', 'data', 'Immutable Fields', 'BEFORE UPDATE trigger that prevents changes to a list of specified fields after INSERT. Raises an exception if any of the listed fields have changed. Unlike FieldImmutable (single-field), this handles multiple fields in a single trigger for efficiency.', CAST(E'{"type":"object","properties":{"fields":{"type":"array","items":{"type":"string","format":"column-ref"},"description":"Field names that cannot be modified after INSERT (e.g. [\\"key\\", \\"bucket_id\\", \\"owner_id\\"])"}},"required":["fields"]}' AS jsonb), CAST('{"trigger","constraint","schema"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('DataInflection', 'data_inflection', 'data', 'Inflection', 'Transforms field values using inflection operations (snake_case, camelCase, slugify, plural, singular, etc). Attaches BEFORE INSERT and BEFORE UPDATE triggers. References fields by name in data jsonb.', '{"type":"object","properties":{"field_name":{"type":"string","format":"column-ref","description":"Name of the field to transform"},"ops":{"type":"array","items":{"type":"string","enum":["plural","singular","camel","pascal","dashed","slugify","underscore","lower","upper"]},"description":"Inflection operations to apply in order"}},"required":["field_name","ops"]}'::jsonb, CAST('{"transform","behavior"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('DataInheritFromParent', 'data_inherit_from_parent', 'data', 'Inherit From Parent', 'BEFORE INSERT trigger that copies specified fields from a parent table via a foreign key. The parent row is looked up through RLS (SECURITY INVOKER), so the insert fails if the caller cannot see the parent. Used by the storage module to inherit owner_id and is_public from buckets to files.', CAST(E'{"type":"object","properties":{"parent_fk_field":{"type":"string","format":"column-ref","description":"Name of the FK field on this table that references the parent (e.g. bucket_id)"},"fields":{"type":"array","items":{"type":"string","format":"column-ref"},"description":"Field names to copy from the parent row (e.g. [\\"owner_id\\", \\"is_public\\"])"},"parent_table":{"type":"string","description":"Parent table name (optional fallback if FK not yet registered in metaschema)"},"parent_schema":{"type":"string","description":"Parent table schema (optional, defaults to same schema as child table)"}},"required":["parent_fk_field","fields"]}' AS jsonb), CAST('{"trigger","inheritance","schema"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('DataJobTrigger', 'data_job_trigger', 'data', 'Job Trigger', 'Dynamically creates PostgreSQL triggers that enqueue jobs via app_jobs.add_job() when table rows are inserted, updated, or deleted. Supports configurable payload strategies (full row, row ID, selected fields, or custom mapping), conditional firing via WHEN clauses, watched field changes, and extended job options (queue, priority, delay, max attempts).', CAST(E'{"type":"object","$defs":{"triggerCondition":{"type":"object","description":"A leaf condition ({field, op, value?, row?, ref?}) or a combinator ({AND, OR, NOT}).","properties":{"field":{"type":"string","format":"column-ref","description":"Column name (validated against the table)."},"op":{"type":"string","enum":["=","!=",">","<",">=","<=","LIKE","NOT LIKE","IS NULL","IS NOT NULL","IS DISTINCT FROM"],"description":"Comparison operator."},"value":{"description":"Comparison value. Type is resolved from the column definition. Omit for IS NULL, IS NOT NULL, IS DISTINCT FROM."},"row":{"type":"string","enum":["NEW","OLD"],"default":"NEW","description":"Row reference (default: NEW)."},"ref":{"type":"object","description":"Column reference for field-to-field comparison (alternative to value).","properties":{"field":{"type":"string","format":"column-ref"},"row":{"type":"string","enum":["NEW","OLD"],"default":"NEW"}}},"AND":{"type":"array","description":"Array of conditions combined with AND.","items":{"$ref":"#/$defs/triggerCondition"}},"OR":{"type":"array","description":"Array of conditions combined with OR.","items":{"$ref":"#/$defs/triggerCondition"}},"NOT":{"$ref":"#/$defs/triggerCondition","description":"Negated condition."}}}},"properties":{"task_identifier":{"type":"string","description":"Job task identifier passed to add_job (e.g., process_invoice, sync_to_stripe)"},"payload_strategy":{"type":"string","enum":["row","row_id","fields","custom"],"description":"How to build the job payload: row (full NEW/OLD), row_id (just id), fields (selected columns), custom (mapped columns)","default":"row_id"},"payload_fields":{"type":"array","items":{"type":"string","format":"column-ref"},"description":"Column names to include in payload (only for fields strategy)"},"payload_custom":{"type":"object","additionalProperties":{"type":"string","format":"column-ref"},"description":"Key-to-column mapping for custom payload (e.g., {\\"invoice_id\\": \\"id\\", \\"total\\": \\"amount\\"})"},"events":{"type":"array","items":{"type":"string","enum":["INSERT","UPDATE","DELETE"]},"description":"Trigger events to create","default":["INSERT","UPDATE"]},"include_old":{"type":"boolean","description":"Include OLD row in payload (for UPDATE triggers)","default":false},"include_meta":{"type":"boolean","description":"Include table/schema metadata in payload","default":false},"condition_field":{"type":"string","format":"column-ref","description":"Column name for conditional WHEN clause (fires only when field equals condition_value)"},"condition_value":{"type":"string","description":"Value to compare against condition_field in WHEN clause"},"conditions":{"description":"Compound conditions for the trigger WHEN clause. Accepts a single leaf condition, an array of conditions (implicitly AND), or a nested combinator tree ({AND: [...], OR: [...], NOT: {...}}). Each leaf is {field, op, value?, row?, ref?}. Column types are resolved automatically from the table schema. Cannot be combined with condition_field or watch_fields.","x-codegen-type":"TriggerCondition | TriggerCondition[]","oneOf":[{"$ref":"#/$defs/triggerCondition"},{"type":"array","items":{"$ref":"#/$defs/triggerCondition"}}]},"watch_fields":{"type":"array","items":{"type":"string","format":"column-ref"},"description":"For UPDATE triggers, only fire when these fields change (uses DISTINCT FROM)"},"job_key":{"type":"string","description":"Static job key for upsert semantics (prevents duplicate jobs)"},"queue_name":{"type":"string","description":"Job queue name for routing to specific workers"},"priority":{"type":"integer","description":"Job priority (lower = higher priority)","default":0},"run_at_delay":{"type":"string","description":"Delay before job runs as PostgreSQL interval (e.g., 30 seconds, 5 minutes)"},"max_attempts":{"type":"integer","description":"Maximum retry attempts for the job","default":25}},"required":["task_identifier"]}' AS jsonb), CAST('{"jobs","triggers","async"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('DataJsonb', 'data_jsonb', 'data', 'JSONB Field', 'Adds a JSONB column with optional GIN index for containment queries (@>, ?, ?|, ?&). Standard pattern for semi-structured metadata.', '{"type":"object","properties":{"field_name":{"type":"string","format":"column-ref","description":"Column name for the JSONB field","default":"metadata"},"default_value":{"type":"string","description":"Default value expression"},"is_required":{"type":"boolean","description":"Whether the column has a NOT NULL constraint","default":false},"create_index":{"type":"boolean","description":"Whether to create a GIN index","default":true}}}'::jsonb, CAST('{"jsonb","schema"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('DataLimitCounter', 'data_limit_counter', 'data', 'Limit Counter', 'Declaratively attaches limit-tracking triggers to a table. On INSERT the named limit is incremented; on DELETE it is decremented. Requires a provisioned limits_module for the target scope.', CAST(E'{"type":"object","properties":{"limit_name":{"type":"string","description":"Name of the limit to track (must match a default_limits entry, e.g. \\"projects\\", \\"members\\")"},"scope":{"type":"string","enum":["app","org"],"description":"Limit scope: \\"app\\" (membership_type=1, user-level) or \\"org\\" (membership_type=2, entity-level)","default":"app"},"actor_field":{"type":"string","format":"column-ref","description":"Column on the target table that holds the actor or entity id used for limit lookup","default":"owner_id"},"events":{"type":"array","items":{"type":"string","enum":["INSERT","DELETE","UPDATE"]},"description":"Which DML events to attach triggers for","default":["INSERT","DELETE"]}},"required":["limit_name"]}' AS jsonb), CAST('{"limits","triggers","billing"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('DataOwnedFields', 'data_owned_fields', 'data', 'Owned Fields', 'Restricts which user can modify specific columns in shared objects. Creates an AFTER UPDATE trigger that throws OWNED_PROPS when a non-owner tries to change protected fields. References fields by name in data jsonb.', CAST('{"type":"object","properties":{"role_key_field_name":{"type":"string","format":"column-ref","description":"Name of the field identifying the owner (e.g. sender_id)"},"protected_field_names":{"type":"array","items":{"type":"string","format":"column-ref"},"description":"Names of fields only this owner can modify"}},"required":["role_key_field_name","protected_field_names"]}' AS jsonb), CAST('{"ownership","constraint","behavior"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('DataOwnershipInEntity', 'data_ownership_in_entity', 'data', 'Ownership In Entity', 'Combines direct ownership with entity scoping. Adds both owner_id and entity_id columns. Enables AuthzDirectOwner, AuthzEntityMembership, and AuthzOrgHierarchy authorization. Particularly useful for OrgHierarchy where a user owns a row (owner_id) within an entity (entity_id), and managers above can see subordinate-owned records via the hierarchy closure table.', '{"type":"object","properties":{"owner_field_name":{"type":"string","format":"column-ref","description":"Column name for the owner reference","default":"owner_id"},"entity_field_name":{"type":"string","format":"column-ref","description":"Column name for the entity reference","default":"entity_id"},"include_id":{"type":"boolean","description":"If true, also adds a UUID primary key column with auto-generation","default":true},"include_user_fk":{"type":"boolean","description":"If true, adds foreign key constraints from owner_id and entity_id to the users table","default":true}}}'::jsonb, CAST('{"ownership","membership","hierarchy","schema"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('DataPeoplestamps', 'data_peoplestamps', 'data', 'Peoplestamps', 'Adds user tracking for creates/updates with created_by and updated_by columns.', '{"type":"object","properties":{"created_by_field":{"type":"string","format":"column-ref","description":"Column name for the creating user reference","default":"created_by"},"updated_by_field":{"type":"string","format":"column-ref","description":"Column name for the last-updating user reference","default":"updated_by"},"include_id":{"type":"boolean","description":"If true, also adds a UUID primary key column with auto-generation","default":true},"include_user_fk":{"type":"boolean","description":"If true, adds foreign key constraints from created_by and updated_by to the users table","default":false}}}'::jsonb, CAST('{"timestamps","schema"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('DataPublishable', 'data_publishable', 'data', 'Publishable', 'Adds publish state columns (is_published, published_at) for content visibility. Enables AuthzPublishable and AuthzTemporal authorization.', '{"type":"object","properties":{"is_published_field":{"type":"string","format":"column-ref","description":"Column name for the published boolean flag","default":"is_published"},"published_at_field":{"type":"string","format":"column-ref","description":"Column name for the publish timestamp","default":"published_at"},"include_id":{"type":"boolean","description":"If true, also adds a UUID primary key column with auto-generation","default":true}}}'::jsonb, CAST('{"publishing","temporal","schema"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('DataSlug', 'data_slug', 'data', 'Slug', 'Auto-generates URL-friendly slugs from field values on insert/update. Attaches BEFORE INSERT and BEFORE UPDATE triggers that call inflection.slugify() on the target field. References fields by name in data jsonb.', CAST('{"type":"object","properties":{"field_name":{"type":"string","format":"column-ref","description":"Name of the field to slugify"},"source_field_name":{"type":"string","format":"column-ref","description":"Optional source field name (defaults to field_name)"}},"required":["field_name"]}' AS jsonb), CAST('{"transform","behavior"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('DataSoftDelete', 'data_soft_delete', 'data', 'Soft Delete', 'Adds soft delete support with deleted_at and is_deleted columns.', '{"type":"object","properties":{"deleted_at_field":{"type":"string","format":"column-ref","description":"Column name for the soft-delete timestamp","default":"deleted_at"},"is_deleted_field":{"type":"string","format":"column-ref","description":"Column name for the soft-delete boolean flag","default":"is_deleted"},"include_id":{"type":"boolean","description":"If true, also adds a UUID primary key column with auto-generation","default":true}}}'::jsonb, CAST('{"schema"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('DataStatusField', 'data_status_field', 'data', 'Status Field', 'Adds a status column with B-tree index for efficient equality filtering and sorting. Optionally constrains values via CHECK constraint when allowed_values is provided.', CAST('{"type":"object","properties":{"field_name":{"type":"string","format":"column-ref","description":"Column name for the status field","default":"status"},"type":{"type":"string","description":"Column type (text or citext)","default":"text"},"default_value":{"type":"string","description":"Default value expression (e.g., active)"},"is_required":{"type":"boolean","description":"Whether the column has a NOT NULL constraint","default":true},"allowed_values":{"type":"array","items":{"type":"string"},"description":"If provided, creates a CHECK constraint restricting the column to these values"}}}' AS jsonb), CAST('{"status","schema"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('DataTags', 'data_tags', 'data', 'Tags', 'Adds a citext[] tags column with GIN index for efficient array containment queries (@>, &&). Standard tagging pattern for categorization and filtering.', '{"type":"object","properties":{"field_name":{"type":"string","format":"column-ref","description":"Column name for the tags array","default":"tags"},"default_value":{"type":"string","description":"Default value expression for the tags column"},"is_required":{"type":"boolean","description":"Whether the column has a NOT NULL constraint","default":false}}}'::jsonb, CAST('{"tags","schema"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('DataTimestamps', 'data_timestamps', 'data', 'Timestamps', 'Adds automatic timestamp tracking with created_at and updated_at columns.', '{"type":"object","properties":{"created_at_field":{"type":"string","format":"column-ref","description":"Column name for the creation timestamp","default":"created_at"},"updated_at_field":{"type":"string","format":"column-ref","description":"Column name for the last-updated timestamp","default":"updated_at"},"include_id":{"type":"boolean","description":"If true, also adds a UUID primary key column with auto-generation","default":true}}}'::jsonb, CAST('{"timestamps","schema"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('RelationBelongsTo', 'relation_belongs_to', 'relation', 'Belongs To', 'Creates a foreign key field on the source table referencing the target table. Auto-derives the FK field name from the target table name using inflection (e.g., projects derives project_id). delete_action is required and must be explicitly provided by the caller.', CAST('{"type":"object","properties":{"source_table_id":{"type":"string","format":"uuid","description":"Table that will have the FK field added"},"target_table_id":{"type":"string","format":"uuid","description":"Table being referenced by the FK"},"field_name":{"type":"string","format":"column-ref","description":"FK field name on the source table. Auto-derived from target table name if omitted (e.g., projects → project_id)"},"delete_action":{"type":"string","enum":["c","r","n","d","a"],"description":"FK delete action: c=CASCADE, r=RESTRICT, n=SET NULL, d=SET DEFAULT, a=NO ACTION. Required."},"is_required":{"type":"boolean","description":"Whether the FK field is NOT NULL","default":true}},"required":["source_table_id","target_table_id","delete_action"]}' AS jsonb), CAST('{"relation","foreign_key","schema"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('RelationHasMany', 'relation_has_many', 'relation', 'Has Many', 'Creates a foreign key field on the target table referencing the source table. Inverse of RelationBelongsTo — same FK, different perspective. "projects has many tasks" creates tasks.project_id. Auto-derives the FK field name from the source table name using inflection. delete_action is required and must be explicitly provided by the caller.', CAST('{"type":"object","properties":{"source_table_id":{"type":"string","format":"uuid","description":"Parent table being referenced by the FK (e.g., projects in projects has many tasks)"},"target_table_id":{"type":"string","format":"uuid","description":"Child table that receives the FK field (e.g., tasks in projects has many tasks)"},"field_name":{"type":"string","format":"column-ref","description":"FK field name on the target table. Auto-derived from source table name if omitted (e.g., projects derives project_id)"},"delete_action":{"type":"string","enum":["c","r","n","d","a"],"description":"FK delete action: c=CASCADE, r=RESTRICT, n=SET NULL, d=SET DEFAULT, a=NO ACTION. Required."},"is_required":{"type":"boolean","description":"Whether the FK field is NOT NULL","default":true}},"required":["source_table_id","target_table_id","delete_action"]}' AS jsonb), CAST('{"relation","foreign_key","has_many","schema"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('RelationHasOne', 'relation_has_one', 'relation', 'Has One', 'Creates a foreign key field with a unique constraint on the source table referencing the target table. Enforces 1:1 cardinality. Auto-derives the FK field name from the target table name using inflection. delete_action is required and must be explicitly provided by the caller.', CAST('{"type":"object","properties":{"source_table_id":{"type":"string","format":"uuid","description":"Table that will have the FK field and unique constraint"},"target_table_id":{"type":"string","format":"uuid","description":"Table being referenced by the FK"},"field_name":{"type":"string","format":"column-ref","description":"FK field name on the source table. Auto-derived from target table name if omitted (e.g., users → user_id)"},"delete_action":{"type":"string","enum":["c","r","n","d","a"],"description":"FK delete action: c=CASCADE, r=RESTRICT, n=SET NULL, d=SET DEFAULT, a=NO ACTION. Required."},"is_required":{"type":"boolean","description":"Whether the FK field is NOT NULL","default":true}},"required":["source_table_id","target_table_id","delete_action"]}' AS jsonb), CAST('{"relation","foreign_key","unique","schema"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('RelationManyToMany', 'relation_many_to_many', 'relation', 'Many to Many', 'Creates a junction table between source and target tables with auto-derived naming and FK fields. The trigger creates a bare table (no implicit DataId), adds FK fields to both tables, optionally creates a composite PK (use_composite_key), then forwards all security config to secure_table_provision as-is. The trigger never injects values the caller did not provide. Junction table FKs always CASCADE on delete.', CAST('{"type":"object","properties":{"source_table_id":{"type":"string","format":"uuid","description":"First table in the M:N relationship"},"target_table_id":{"type":"string","format":"uuid","description":"Second table in the M:N relationship"},"junction_table_id":{"type":"string","format":"uuid","description":"Existing junction table to use. If uuid_nil(), a new bare table is created"},"junction_table_name":{"type":"string","description":"Junction table name. Auto-derived from both table names if omitted (e.g., projects + tags derives project_tags)"},"source_field_name":{"type":"string","format":"column-ref","description":"FK field name on junction for source table. Auto-derived if omitted (e.g., projects derives project_id)"},"target_field_name":{"type":"string","format":"column-ref","description":"FK field name on junction for target table. Auto-derived if omitted (e.g., tags derives tag_id)"},"use_composite_key":{"type":"boolean","description":"When true, creates a composite PK from the two FK fields. When false, no PK is created by the trigger (use nodes with DataId for UUID PK). Mutually exclusive with nodes containing DataId.","default":false},"nodes":{"type":"array","items":{"type":"object"},"description":"Array of node objects for field creation on junction table. Each object has a $type key (e.g. DataId, DataEntityMembership) and optional data keys. Forwarded to secure_table_provision as-is. Empty array means no additional fields."},"grants":{"type":"array","items":{"type":"object","properties":{"roles":{"type":"array","items":{"type":"string"}},"privileges":{"type":"array","items":{"type":"array","items":{"type":"string"}}}},"required":["roles","privileges"]},"description":"Unified grant objects for the junction table. Each entry is { roles: string[], privileges: string[][] }. Forwarded to secure_table_provision as-is. Default: []"},"policies":{"type":"array","items":{"type":"object","properties":{"$type":{"type":"string"},"data":{"type":"object"},"privileges":{"type":"array","items":{"type":"string"}},"policy_role":{"type":"string"},"permissive":{"type":"boolean"},"policy_name":{"type":"string"}},"required":["$type"]},"description":"RLS policy objects for the junction table. Each entry has $type (Authz* generator), optional data, privileges, policy_role, permissive, policy_name. Forwarded to secure_table_provision as-is. Default: []"}},"required":["source_table_id","target_table_id"]}' AS jsonb), CAST('{"relation","junction","many_to_many","schema"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('RelationSpatial', 'relation_spatial', 'relation', 'Spatial Relation', 'Declares a spatial predicate between two existing geometry/geography columns. Inserts a metaschema_public.spatial_relation row; the sync_spatial_relation_tags trigger then projects a @spatialRelation smart tag onto the owner column so graphile-postgis'' PostgisSpatialRelationsPlugin can expose it as a cross-table filter in GraphQL. Metadata-only: both source_field and target_field must already exist on their tables. Idempotent on (source_table_id, name). One direction per tag — author two RelationSpatial entries if symmetry is desired.', CAST('{"type":"object","properties":{"source_table_id":{"type":"string","format":"uuid","description":"Table that owns the relation (the @spatialRelation tag is emitted on the owner column of this table)"},"source_field_id":{"type":"string","format":"uuid","description":"Geometry/geography column on source_table that carries the @spatialRelation smart tag"},"target_table_id":{"type":"string","format":"uuid","description":"Table being referenced by the spatial predicate"},"target_field_id":{"type":"string","format":"uuid","description":"Geometry/geography column on target_table that the predicate is evaluated against"},"name":{"type":"string","description":"Relation name (stable, snake_case). Becomes the generated filter field name in GraphQL (e.g. nearby_clinic). Unique per (source_table_id, name) — idempotency key."},"operator":{"type":"string","enum":["st_contains","st_within","st_intersects","st_covers","st_coveredby","st_overlaps","st_touches","st_dwithin"],"description":"PostGIS spatial predicate. One of the 8 whitelisted operators. st_dwithin requires param_name."},"param_name":{"type":"string","description":"Parameter name for parametric operators (currently only st_dwithin, which needs a distance argument). Must be NULL for all other operators. Enforced by table CHECK."}},"required":["source_table_id","source_field_id","target_table_id","target_field_id","name","operator"]}' AS jsonb), CAST('{"relation","spatial","postgis","schema"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('SearchBm25', 'search_bm25', 'search', 'BM25 Search', 'Creates a BM25 index on an existing text column using pg_textsearch. Enables statistical relevance ranking with configurable k1 and b parameters. The BM25 index is auto-detected by graphile-search.', CAST('{"type":"object","properties":{"field_name":{"type":"string","format":"column-ref","description":"Name of existing text column to index with BM25"},"text_config":{"type":"string","description":"PostgreSQL text search configuration for BM25","default":"english"},"k1":{"type":"number","description":"BM25 k1 parameter: term frequency saturation (typical: 1.2-2.0)","default":null},"b":{"type":"number","description":"BM25 b parameter: document length normalization (0=none, 1=full, typical: 0.75)","default":null},"search_score_weight":{"type":"number","description":"Weight for this algorithm in composite searchScore","default":1}},"required":["field_name"]}' AS jsonb), CAST('{"search","bm25","schema"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('SearchFullText', 'search_full_text', 'search', 'Full-Text Search', 'Adds a tsvector column with GIN index and automatic trigger population from source fields. Enables PostgreSQL full-text search with configurable weights and language support. Leverages the existing metaschema full_text_search infrastructure.', CAST('{"type":"object","properties":{"field_name":{"type":"string","format":"column-ref","description":"Name of the tsvector column","default":"search"},"source_fields":{"type":"array","items":{"type":"object","properties":{"field":{"type":"string","format":"column-ref","description":"Name of the source column"},"weight":{"type":"string","enum":["A","B","C","D"],"description":"tsvector weight class (A=highest, D=lowest)","default":"D"},"lang":{"type":"string","description":"PostgreSQL text search configuration","default":"english"}},"required":["field"]},"description":"Source columns that feed the tsvector. Each has a field name, weight (A-D), and language config."},"search_score_weight":{"type":"number","description":"Weight for this algorithm in composite searchScore","default":1}},"required":["source_fields"]}' AS jsonb), CAST('{"search","fts","tsvector","schema"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('SearchSpatial', 'search_spatial', 'search', 'Spatial Search', 'Adds a PostGIS geometry or geography column with a spatial index (GiST or SP-GiST). Supports configurable geometry types (Point, Polygon, etc.), SRID, and dimensionality. The graphile-postgis plugin auto-detects geometry/geography columns by codec type for spatial filtering (ST_Contains, ST_DWithin, bbox operators).', CAST('{"type":"object","properties":{"field_name":{"type":"string","format":"column-ref","description":"Name of the geometry/geography column","default":"geom"},"geometry_type":{"type":"string","enum":["Point","LineString","Polygon","MultiPoint","MultiLineString","MultiPolygon","GeometryCollection","Geometry"],"description":"PostGIS geometry type constraint","default":"Point"},"srid":{"type":"integer","description":"Spatial Reference System Identifier (e.g. 4326 for WGS84)","default":4326},"dimension":{"type":"integer","enum":[2,3,4],"description":"Coordinate dimension (2=XY, 3=XYZ, 4=XYZM)","default":2},"use_geography":{"type":"boolean","description":"Use geography type instead of geometry (for geodetic calculations on the sphere)","default":false},"index_method":{"type":"string","enum":["gist","spgist"],"description":"Spatial index method","default":"gist"}}}' AS jsonb), CAST('{"spatial","postgis","geometry","schema"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('SearchSpatialAggregate', 'search_spatial_aggregate', 'search', 'Spatial Aggregate Search', 'Creates a derived/materialized geometry field on the parent table that automatically aggregates geometries from a source (child) table via triggers. When child rows are inserted/updated/deleted, the parent aggregate field is recalculated using the specified PostGIS aggregation function (ST_Union, ST_Collect, ST_ConvexHull, ST_ConcaveHull). Useful for materializing spatial boundaries from collections of points or polygons.', CAST('{"type":"object","properties":{"field_name":{"type":"string","format":"column-ref","description":"Name of the aggregate geometry column on the parent table","default":"geom_aggregate"},"source_table_id":{"type":"string","format":"uuid","description":"UUID of the source (child) table containing individual geometries"},"source_geom_field":{"type":"string","format":"column-ref","description":"Name of the geometry column on the source table","default":"geom"},"source_fk_field":{"type":"string","format":"column-ref","description":"Name of the foreign key column on the source table pointing to the parent"},"aggregate_function":{"type":"string","enum":["union","collect","convex_hull","concave_hull"],"description":"PostGIS aggregation function: union (ST_Union, merges overlapping), collect (ST_Collect, groups without merging), convex_hull (smallest convex polygon), concave_hull (tighter boundary)","default":"union"},"geometry_type":{"type":"string","enum":["Point","LineString","Polygon","MultiPoint","MultiLineString","MultiPolygon","GeometryCollection","Geometry"],"description":"Output geometry type constraint for the aggregate field","default":"MultiPolygon"},"srid":{"type":"integer","description":"Spatial Reference System Identifier (e.g. 4326 for WGS84)","default":4326},"dimension":{"type":"integer","enum":[2,3,4],"description":"Coordinate dimension (2=XY, 3=XYZ, 4=XYZM)","default":2},"use_geography":{"type":"boolean","description":"Use geography type instead of geometry","default":false},"index_method":{"type":"string","enum":["gist","spgist"],"description":"Spatial index method for the aggregate field","default":"gist"}},"required":["source_table_id","source_fk_field"]}' AS jsonb), CAST('{"spatial","postgis","geometry","aggregate","schema"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('SearchTrgm', 'search_trgm', 'search', 'Trigram Search', 'Creates GIN trigram indexes (gin_trgm_ops) on specified text/citext fields for fuzzy LIKE/ILIKE/similarity search. Adds @trgmSearch smart tag for PostGraphile integration. Fields must already exist on the table.', CAST('{"type":"object","properties":{"fields":{"type":"array","items":{"type":"string","format":"column-ref"},"description":"Field names to create trigram indexes on (fields must already exist on the table)"}},"required":["fields"]}' AS jsonb), CAST('{"search","trigram","schema"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('SearchUnified', 'search_unified', 'search', 'Unified Search', 'Composite node type that orchestrates multiple search modalities (full-text search, BM25, embeddings, trigram) on a single table. Configures per-table search score weights, normalization strategy, and recency boost via the @searchConfig smart tag.', CAST('{"type":"object","properties":{"full_text_search":{"type":"object","description":"SearchFullText parameters. Omit to skip FTS setup.","properties":{"field_name":{"type":"string","format":"column-ref","default":"search"},"source_fields":{"type":"array","items":{"type":"object","properties":{"field":{"type":"string","format":"column-ref"},"weight":{"type":"string","enum":["A","B","C","D"]},"lang":{"type":"string"}},"required":["field"]}},"search_score_weight":{"type":"number","default":1}}},"bm25":{"type":"object","description":"SearchBm25 parameters. Omit to skip BM25 setup.","properties":{"field_name":{"type":"string","format":"column-ref"},"text_config":{"type":"string","default":"english"},"k1":{"type":"number"},"b":{"type":"number"},"search_score_weight":{"type":"number","default":1}}},"embedding":{"type":"object","description":"SearchVector parameters. Omit to skip embedding setup.","properties":{"field_name":{"type":"string","format":"column-ref","default":"embedding"},"dimensions":{"type":"integer","default":768},"index_method":{"type":"string","enum":["hnsw","ivfflat"]},"metric":{"type":"string","enum":["cosine","l2","ip"]},"source_fields":{"type":"array","items":{"type":"string","format":"column-ref"}},"search_score_weight":{"type":"number","default":1},"chunks":{"type":"object","description":"Chunking configuration for long-text embedding. Creates an embedding_chunks record that drives automatic text splitting and per-chunk embedding. Omit to skip chunking.","properties":{"content_field_name":{"type":"string","format":"column-ref","description":"Name of the text content column in the chunks table","default":"content"},"chunk_size":{"type":"integer","description":"Maximum number of characters per chunk","default":1000},"chunk_overlap":{"type":"integer","description":"Number of overlapping characters between consecutive chunks","default":200},"chunk_strategy":{"type":"string","enum":["fixed","sentence","paragraph","semantic"],"description":"Strategy for splitting text into chunks","default":"fixed"},"metadata_fields":{"type":"object","description":"Metadata fields from parent to copy into chunks"},"enqueue_chunking_job":{"type":"boolean","description":"Whether to auto-enqueue a chunking job on insert/update","default":true},"chunking_task_name":{"type":"string","description":"Task identifier for the chunking job queue","default":"generate_chunks"}}}}},"trgm_fields":{"type":"array","items":{"type":"string","format":"column-ref"},"description":"Field names to tag with @trgmSearch for fuzzy/typo-tolerant matching"},"search_config":{"type":"object","description":"Unified search score configuration written to @searchConfig smart tag","properties":{"weights":{"type":"object","description":"Per-algorithm weights: {tsv: 1.5, bm25: 1.0, pgvector: 0.8, trgm: 0.3}"},"normalization":{"type":"string","enum":["linear","sigmoid"],"description":"Score normalization strategy","default":"linear"},"boost_recent":{"type":"boolean","description":"Enable recency boost for search results","default":false},"boost_recency_field":{"type":"string","format":"column-ref","description":"Timestamp field for recency boost (e.g. created_at, updated_at)"},"boost_recency_decay":{"type":"number","description":"Decay rate for recency boost (0-1, lower = faster decay)","default":0.5}}}}}' AS jsonb), CAST('{"search","composite","schema"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('SearchVector', 'search_vector', 'search', 'Vector Search', 'Adds a vector embedding column with HNSW or IVFFlat index for similarity search. Supports configurable dimensions, distance metrics (cosine, l2, ip), stale tracking strategies (column, null, hash), and automatic job enqueue triggers for embedding generation.', CAST('{"type":"object","properties":{"field_name":{"type":"string","format":"column-ref","description":"Name of the vector column","default":"embedding"},"dimensions":{"type":"integer","description":"Vector dimensions (e.g. 384, 768, 1536, 3072)","default":768},"index_method":{"type":"string","enum":["hnsw","ivfflat"],"description":"Index type for similarity search","default":"hnsw"},"metric":{"type":"string","enum":["cosine","l2","ip"],"description":"Distance metric (cosine, l2, ip)","default":"cosine"},"index_options":{"type":"object","description":"Index-specific options. HNSW: {m, ef_construction}. IVFFlat: {lists}.","default":{}},"include_stale_field":{"type":"boolean","description":"When stale_strategy is column, adds an embedding_stale boolean field","default":true},"source_fields":{"type":"array","items":{"type":"string","format":"column-ref"},"description":"Column names that feed the embedding. Used by stale trigger to detect content changes."},"enqueue_job":{"type":"boolean","description":"Auto-create trigger that enqueues embedding generation jobs","default":true},"job_task_name":{"type":"string","description":"Task identifier for the job queue","default":"generate_embedding"},"stale_strategy":{"type":"string","enum":["column","null","hash"],"description":"Strategy for tracking embedding staleness. column: embedding_stale boolean. null: set embedding to NULL. hash: md5 hash of source fields.","default":"column"},"chunks":{"type":"object","description":"Chunking configuration for long-text embedding. Creates an embedding_chunks record that drives automatic text splitting and per-chunk embedding. Omit to skip chunking.","properties":{"content_field_name":{"type":"string","format":"column-ref","description":"Name of the text content column in the chunks table","default":"content"},"chunk_size":{"type":"integer","description":"Maximum number of characters per chunk","default":1000},"chunk_overlap":{"type":"integer","description":"Number of overlapping characters between consecutive chunks","default":200},"chunk_strategy":{"type":"string","enum":["fixed","sentence","paragraph","semantic"],"description":"Strategy for splitting text into chunks","default":"fixed"},"metadata_fields":{"type":"object","description":"Metadata fields from parent to copy into chunks"},"enqueue_chunking_job":{"type":"boolean","description":"Whether to auto-enqueue a chunking job on insert/update","default":true},"chunking_task_name":{"type":"string","description":"Task identifier for the chunking job queue","default":"generate_chunks"}}}}}' AS jsonb), CAST('{"embedding","vector","ai","schema"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('TableOrganizationSettings', 'table_organization_settings', 'data', 'Organization Settings', 'Creates an organization settings table with standard business fields (legal_name, address fields). Uses AuthzEntityMembership for access control.', '{"type":"object","properties":{}}'::jsonb, CAST('{"template","settings","membership","schema"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('TableUserProfiles', 'table_user_profiles', 'data', 'User Profiles', 'Creates a user profiles table with standard profile fields (profile_picture, bio, first_name, last_name, tags, desired). Uses AuthzDirectOwner for edit access and AuthzAllowAll for select.', '{"type":"object","properties":{}}'::jsonb, CAST('{"template","settings","ownership","schema"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('TableUserSettings', 'table_user_settings', 'data', 'User Settings', 'Creates a user settings table for user-specific configuration. Uses AuthzDirectOwner for access control.', '{"type":"object","properties":{}}'::jsonb, CAST('{"template","settings","ownership","schema"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('ViewAggregated', 'view_aggregated', 'view', 'Aggregated View', 'View with GROUP BY and aggregate functions. Useful for summary/reporting views.', CAST('{"type":"object","properties":{"source_table_id":{"type":"string","format":"uuid","description":"UUID of the source table"},"group_by_fields":{"type":"array","items":{"type":"string","format":"column-ref"},"description":"Field names to group by"},"aggregates":{"type":"array","items":{"type":"object","properties":{"function":{"type":"string","enum":["COUNT","SUM","AVG","MIN","MAX"]},"field":{"type":"string","format":"column-ref","description":"Field to aggregate (or * for COUNT)"},"alias":{"type":"string","format":"column-ref","description":"Output column name"}},"required":["function","alias"]},"description":"Array of aggregate specifications"}},"required":["source_table_id","group_by_fields","aggregates"]}' AS jsonb), CAST('{"view","aggregate","reporting"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('ViewComposite', 'view_composite', 'view', 'Composite View', 'Advanced view using composite AST for the query. Use when other node types are insufficient (CTEs, UNIONs, complex subqueries, etc.).', CAST('{"type":"object","properties":{"query_ast":{"type":"object","description":"Composite SELECT query AST (JSONB)"}},"required":["query_ast"]}' AS jsonb), CAST('{"view","advanced","composite","ast"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('ViewFilteredTable', 'view_filtered_table', 'view', 'Filtered Table', 'Table projection with an Authz* filter baked into the view definition. The view only returns records matching the filter.', CAST('{"type":"object","properties":{"source_table_id":{"type":"string","format":"uuid","description":"UUID of the source table"},"filter_type":{"type":"string","description":"Authz* node type name (e.g., AuthzDirectOwner, AuthzPublishable)"},"filter_data":{"type":"object","description":"Parameters for the Authz* filter type"},"field_ids":{"type":"array","items":{"type":"string","format":"uuid"},"description":"Optional array of field UUIDs to include (alternative to field_names)"},"field_names":{"type":"array","items":{"type":"string","format":"column-ref"},"description":"Optional array of field names to include (alternative to field_ids)"}},"required":["source_table_id","filter_type"]}' AS jsonb), CAST('{"view","filter","authz"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('ViewJoinedTables', 'view_joined_tables', 'view', 'Joined Tables', 'View that joins multiple tables together. Supports INNER, LEFT, RIGHT, and FULL joins.', CAST('{"type":"object","properties":{"primary_table_id":{"type":"string","format":"uuid","description":"UUID of the primary (left-most) table"},"primary_columns":{"type":"array","items":{"type":"string","format":"column-ref"},"description":"Optional array of column names to include from the primary table"},"joins":{"type":"array","items":{"type":"object","properties":{"table_id":{"type":"string","format":"uuid","description":"UUID of the joined table"},"join_type":{"type":"string","enum":["INNER","LEFT","RIGHT","FULL"]},"primary_field":{"type":"string","format":"column-ref","description":"Field on primary table"},"join_field":{"type":"string","format":"column-ref","description":"Field on joined table"},"columns":{"type":"array","items":{"type":"string","format":"column-ref"},"description":"Optional column names to include from this joined table"}},"required":["table_id","primary_field","join_field"]},"description":"Array of join specifications"},"field_ids":{"type":"array","items":{"type":"string","format":"uuid"},"description":"Optional array of field UUIDs to include (alternative to per-table columns)"}},"required":["primary_table_id","joins"]}' AS jsonb), CAST('{"view","join"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;

INSERT INTO metaschema_public.node_type_registry (
  name,
  slug,
  category,
  display_name,
  description,
  parameter_schema,
  tags
) VALUES
  ('ViewTableProjection', 'view_table_projection', 'view', 'Table Projection', 'Simple column selection from a single source table. Projects all or specific fields.', CAST('{"type":"object","properties":{"source_table_id":{"type":"string","format":"uuid","description":"UUID of the source table to project from"},"field_ids":{"type":"array","items":{"type":"string","format":"uuid"},"description":"Optional array of field UUIDs to include (all fields if omitted)"},"field_names":{"type":"array","items":{"type":"string","format":"column-ref"},"description":"Optional array of field names to include (alternative to field_ids)"}},"required":["source_table_id"]}' AS jsonb), CAST('{"view","projection"}' AS text[])) ON CONFLICT (name) DO UPDATE SET slug = excluded.slug, category = excluded.category, display_name = excluded.display_name, description = excluded.description, parameter_schema = excluded.parameter_schema, tags = excluded.tags;