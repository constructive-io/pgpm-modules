\echo Use "CREATE EXTENSION db_meta" to load this file. \quit
CREATE SCHEMA collections_private;

GRANT USAGE ON SCHEMA collections_private TO authenticated;

CREATE SCHEMA collections_public;

GRANT USAGE ON SCHEMA collections_public TO authenticated;

CREATE TABLE collections_public.database (
 	id uuid PRIMARY KEY DEFAULT ( uuid_generate_v4() ),
	owner_id uuid,
	schema_hash text,
	schema_name text,
	private_schema_name text,
	name text,
	UNIQUE ( schema_hash ),
	UNIQUE ( schema_name ),
	UNIQUE ( private_schema_name ) 
);

ALTER TABLE collections_public.database ADD CONSTRAINT db_namechk CHECK ( char_length(name) > 2 );

COMMENT ON COLUMN collections_public.database.schema_hash IS E'@omit';

CREATE TABLE collections_public.schema (
 	id uuid PRIMARY KEY DEFAULT ( uuid_generate_v4() ),
	database_id uuid NOT NULL,
	name text NOT NULL,
	schema_name text NOT NULL,
	description text,
	CONSTRAINT db_fkey FOREIGN KEY ( database_id ) REFERENCES collections_public.database ( id ) ON DELETE CASCADE,
	UNIQUE ( database_id, name ),
	UNIQUE ( schema_name ) 
);

ALTER TABLE collections_public.schema ADD CONSTRAINT schema_namechk CHECK ( char_length(name) > 2 );

COMMENT ON CONSTRAINT db_fkey ON collections_public.schema IS E'@omit manyToMany';

CREATE INDEX schema_database_id_idx ON collections_public.schema ( database_id );

CREATE TABLE collections_public."table" (
 	id uuid PRIMARY KEY DEFAULT ( uuid_generate_v4() ),
	database_id uuid NOT NULL,
	schema_id uuid NOT NULL,
	name text NOT NULL,
	description text,
	smart_tags jsonb,
	is_system boolean DEFAULT ( FALSE ),
	use_rls boolean NOT NULL DEFAULT ( FALSE ),
	plural_name text,
	singular_name text,
	CONSTRAINT db_fkey FOREIGN KEY ( database_id ) REFERENCES collections_public.database ( id ) ON DELETE CASCADE,
	CONSTRAINT schema_fkey FOREIGN KEY ( schema_id ) REFERENCES collections_public.schema ( id ) ON DELETE CASCADE,
	UNIQUE ( database_id, name ) 
);

ALTER TABLE collections_public."table" ADD COLUMN  inherits_id uuid NULL REFERENCES collections_public."table" ( id );

COMMENT ON CONSTRAINT schema_fkey ON collections_public.table IS E'@omit manyToMany';

COMMENT ON CONSTRAINT db_fkey ON collections_public.table IS E'@omit manyToMany';

CREATE INDEX table_schema_id_idx ON collections_public."table" ( schema_id );

CREATE INDEX table_database_id_idx ON collections_public."table" ( database_id );

CREATE TABLE collections_public.check_constraint (
 	id uuid PRIMARY KEY DEFAULT ( uuid_generate_v4() ),
	database_id uuid NOT NULL,
	table_id uuid NOT NULL,
	name text,
	type text,
	field_ids uuid[] NOT NULL,
	expr jsonb,
	CONSTRAINT db_fkey FOREIGN KEY ( database_id ) REFERENCES collections_public.database ( id ) ON DELETE CASCADE,
	CONSTRAINT table_fkey FOREIGN KEY ( table_id ) REFERENCES collections_public."table" ( id ) ON DELETE CASCADE,
	UNIQUE ( database_id, name ),
	CHECK ( field_ids <> '{}' ) 
);

COMMENT ON CONSTRAINT table_fkey ON collections_public.check_constraint IS E'@omit manyToMany';

COMMENT ON CONSTRAINT db_fkey ON collections_public.check_constraint IS E'@omit manyToMany';

CREATE INDEX check_constraint_table_id_idx ON collections_public.check_constraint ( table_id );

CREATE INDEX check_constraint_database_id_idx ON collections_public.check_constraint ( database_id );

CREATE TABLE collections_public.extension (
 	name text NOT NULL PRIMARY KEY,
	public_schemas text[],
	private_schemas text[] 
);

INSERT INTO collections_public.extension ( name, public_schemas, private_schemas ) VALUES ('collections', ARRAY['collections_public'], ARRAY['collections_private']), ('meta', ARRAY['meta_public'], ARRAY['meta_private']);

CREATE TABLE collections_public.database_extension (
 	name text NOT NULL PRIMARY KEY,
	database_id uuid NOT NULL,
	CONSTRAINT ext_fkey FOREIGN KEY ( name ) REFERENCES collections_public.extension ( name ) ON DELETE CASCADE,
	CONSTRAINT db_fkey FOREIGN KEY ( database_id ) REFERENCES collections_public.database ( id ) ON DELETE CASCADE,
	UNIQUE ( database_id, name ) 
);

COMMENT ON CONSTRAINT db_fkey ON collections_public.database_extension IS E'@omit manyToMany';

CREATE INDEX database_extension_database_id_idx ON collections_public.database_extension ( database_id );

CREATE FUNCTION collections_private.database_name_hash ( name text ) RETURNS bytea AS $EOFCODE$
  SELECT
    DECODE(MD5(LOWER(inflection.plural (name))), 'hex');
$EOFCODE$ LANGUAGE sql IMMUTABLE;

CREATE UNIQUE INDEX databases_database_unique_name_idx ON collections_public.database ( owner_id, collections_private.database_name_hash(name) );

CREATE TABLE collections_public.field (
 	id uuid PRIMARY KEY DEFAULT ( uuid_generate_v4() ),
	database_id uuid NOT NULL,
	table_id uuid NOT NULL,
	name text NOT NULL,
	description text,
	smart_tags jsonb,
	is_required boolean NOT NULL DEFAULT ( FALSE ),
	default_value text NULL DEFAULT ( NULL ),
	is_hidden boolean NOT NULL DEFAULT ( FALSE ),
	type citext NOT NULL,
	field_order int NOT NULL DEFAULT ( 0 ),
	regexp text DEFAULT ( NULL ),
	chk jsonb DEFAULT ( NULL ),
	chk_expr jsonb DEFAULT ( NULL ),
	min pg_catalog.float8 DEFAULT ( NULL ),
	max pg_catalog.float8 DEFAULT ( NULL ),
	CONSTRAINT db_fkey FOREIGN KEY ( database_id ) REFERENCES collections_public.database ( id ) ON DELETE CASCADE,
	CONSTRAINT table_fkey FOREIGN KEY ( table_id ) REFERENCES collections_public."table" ( id ) ON DELETE CASCADE,
	UNIQUE ( table_id, name ) 
);

COMMENT ON CONSTRAINT table_fkey ON collections_public.field IS E'@omit manyToMany';

COMMENT ON CONSTRAINT db_fkey ON collections_public.field IS E'@omit manyToMany';

CREATE INDEX field_table_id_idx ON collections_public.field ( table_id );

CREATE INDEX field_database_id_idx ON collections_public.field ( database_id );

CREATE UNIQUE INDEX databases_field_uniq_names_idx ON collections_public.field ( table_id, decode(md5(lower(regexp_replace(name, '^(.+?)(_row_id|_id|_uuid|_fk|_pk)$', '\1', 'i'))), 'hex') );

CREATE TABLE collections_public.foreign_key_constraint (
 	id uuid PRIMARY KEY DEFAULT ( uuid_generate_v4() ),
	database_id uuid NOT NULL,
	table_id uuid NOT NULL,
	name text,
	description text,
	smart_tags jsonb,
	type text,
	field_ids uuid[] NOT NULL,
	ref_table_id uuid NOT NULL REFERENCES collections_public."table" ( id ) ON DELETE CASCADE,
	ref_field_ids uuid[] NOT NULL,
	delete_action char(1) DEFAULT ( 'a' ),
	update_action char(1) DEFAULT ( 'a' ),
	CONSTRAINT db_fkey FOREIGN KEY ( database_id ) REFERENCES collections_public.database ( id ) ON DELETE CASCADE,
	CONSTRAINT table_fkey FOREIGN KEY ( table_id ) REFERENCES collections_public."table" ( id ) ON DELETE CASCADE,
	UNIQUE ( database_id, name ),
	CHECK ( field_ids <> '{}' ),
	CHECK ( ref_field_ids <> '{}' ) 
);

COMMENT ON CONSTRAINT table_fkey ON collections_public.foreign_key_constraint IS E'@omit manyToMany';

COMMENT ON CONSTRAINT db_fkey ON collections_public.foreign_key_constraint IS E'@omit manyToMany';

CREATE INDEX foreign_key_constraint_table_id_idx ON collections_public.foreign_key_constraint ( table_id );

CREATE INDEX foreign_key_constraint_database_id_idx ON collections_public.foreign_key_constraint ( database_id );

CREATE TABLE collections_public.full_text_search (
 	id uuid PRIMARY KEY DEFAULT ( uuid_generate_v4() ),
	database_id uuid NOT NULL,
	table_id uuid NOT NULL,
	field_id uuid NOT NULL,
	field_ids uuid[] NOT NULL,
	weights text[] NOT NULL,
	langs text[] NOT NULL,
	CONSTRAINT db_fkey FOREIGN KEY ( database_id ) REFERENCES collections_public.database ( id ) ON DELETE CASCADE,
	CONSTRAINT table_fkey FOREIGN KEY ( table_id ) REFERENCES collections_public."table" ( id ) ON DELETE CASCADE,
	CHECK ( cardinality(field_ids) = cardinality(weights) AND cardinality(weights) = cardinality(langs) ) 
);

COMMENT ON CONSTRAINT table_fkey ON collections_public.full_text_search IS E'@omit manyToMany';

COMMENT ON CONSTRAINT db_fkey ON collections_public.full_text_search IS E'@omit manyToMany';

CREATE INDEX full_text_search_table_id_idx ON collections_public.full_text_search ( table_id );

CREATE INDEX full_text_search_database_id_idx ON collections_public.full_text_search ( database_id );

CREATE TABLE collections_public.index (
 	id uuid PRIMARY KEY DEFAULT ( uuid_generate_v4() ),
	database_id uuid NOT NULL,
	table_id uuid NOT NULL,
	name text NOT NULL,
	field_ids uuid[],
	CONSTRAINT db_fkey FOREIGN KEY ( database_id ) REFERENCES collections_public.database ( id ) ON DELETE CASCADE,
	CONSTRAINT table_fkey FOREIGN KEY ( table_id ) REFERENCES collections_public."table" ( id ) ON DELETE CASCADE,
	UNIQUE ( database_id, name ) 
);

COMMENT ON CONSTRAINT table_fkey ON collections_public.index IS E'@omit manyToMany';

COMMENT ON CONSTRAINT db_fkey ON collections_public.index IS E'@omit manyToMany';

CREATE INDEX index_table_id_idx ON collections_public.index ( table_id );

CREATE INDEX index_database_id_idx ON collections_public.index ( database_id );

CREATE TABLE collections_public.policy (
 	id uuid PRIMARY KEY DEFAULT ( uuid_generate_v4() ),
	database_id uuid NOT NULL,
	table_id uuid NOT NULL,
	name text,
	role_name text,
	privilege text,
	permissive boolean DEFAULT ( TRUE ),
	policy_template_name text,
	policy_template_vars json,
	CONSTRAINT db_fkey FOREIGN KEY ( database_id ) REFERENCES collections_public.database ( id ) ON DELETE CASCADE,
	CONSTRAINT table_fkey FOREIGN KEY ( table_id ) REFERENCES collections_public."table" ( id ) ON DELETE CASCADE,
	UNIQUE ( table_id, name ) 
);

COMMENT ON CONSTRAINT table_fkey ON collections_public.policy IS E'@omit manyToMany';

COMMENT ON CONSTRAINT db_fkey ON collections_public.policy IS E'@omit manyToMany';

CREATE INDEX policy_table_id_idx ON collections_public.policy ( table_id );

CREATE INDEX policy_database_id_idx ON collections_public.policy ( database_id );

CREATE TABLE collections_public.primary_key_constraint (
 	id uuid PRIMARY KEY DEFAULT ( uuid_generate_v4() ),
	database_id uuid NOT NULL,
	table_id uuid NOT NULL,
	name text,
	type text,
	field_ids uuid[] NOT NULL,
	CONSTRAINT db_fkey FOREIGN KEY ( database_id ) REFERENCES collections_public.database ( id ) ON DELETE CASCADE,
	CONSTRAINT table_fkey FOREIGN KEY ( table_id ) REFERENCES collections_public."table" ( id ) ON DELETE CASCADE,
	UNIQUE ( database_id, name ),
	CHECK ( field_ids <> '{}' ) 
);

COMMENT ON CONSTRAINT table_fkey ON collections_public.primary_key_constraint IS E'@omit manyToMany';

COMMENT ON CONSTRAINT db_fkey ON collections_public.primary_key_constraint IS E'@omit manyToMany';

CREATE INDEX primary_key_constraint_table_id_idx ON collections_public.primary_key_constraint ( table_id );

CREATE INDEX primary_key_constraint_database_id_idx ON collections_public.primary_key_constraint ( database_id );

CREATE TABLE collections_public.procedure (
 	id uuid PRIMARY KEY DEFAULT ( uuid_generate_v4() ),
	database_id uuid NOT NULL,
	name text NOT NULL,
	argnames text[],
	argtypes text[],
	argdefaults text[],
	lang_name text,
	definition text,
	CONSTRAINT db_fkey FOREIGN KEY ( database_id ) REFERENCES collections_public.database ( id ) ON DELETE CASCADE,
	UNIQUE ( database_id, name ) 
);

COMMENT ON CONSTRAINT db_fkey ON collections_public.procedure IS E'@omit manyToMany';

CREATE INDEX procedure_database_id_idx ON collections_public.procedure ( database_id );

CREATE TABLE collections_public.rls_expression (
 	id uuid PRIMARY KEY DEFAULT ( uuid_generate_v4() ),
	expr json 
);

CREATE TABLE collections_public.rls_function (
 	id uuid PRIMARY KEY DEFAULT ( uuid_generate_v4() ),
	database_id uuid NOT NULL,
	name text NOT NULL,
	function_template_name text,
	function_template_vars json,
	label text,
	description text,
	CONSTRAINT db_fkey FOREIGN KEY ( database_id ) REFERENCES collections_public.database ( id ) ON DELETE CASCADE,
	UNIQUE ( function_template_name, database_id ),
	UNIQUE ( database_id, name ) 
);

COMMENT ON CONSTRAINT db_fkey ON collections_public.rls_function IS E'@omit manyToMany';

CREATE INDEX rls_function_database_id_idx ON collections_public.rls_function ( database_id );

CREATE TABLE collections_public.schema_grant (
 	id uuid PRIMARY KEY DEFAULT ( uuid_generate_v4() ),
	database_id uuid NOT NULL,
	schema_id uuid NOT NULL,
	grantee_name text NOT NULL,
	CONSTRAINT db_fkey FOREIGN KEY ( database_id ) REFERENCES collections_public.database ( id ) ON DELETE CASCADE,
	CONSTRAINT schema_fkey FOREIGN KEY ( schema_id ) REFERENCES collections_public.schema ( id ) ON DELETE CASCADE 
);

COMMENT ON CONSTRAINT schema_fkey ON collections_public.schema_grant IS E'@omit manyToMany';

COMMENT ON CONSTRAINT db_fkey ON collections_public.schema_grant IS E'@omit manyToMany';

CREATE INDEX schema_grant_schema_id_idx ON collections_public.schema_grant ( schema_id );

CREATE INDEX schema_grant_database_id_idx ON collections_public.schema_grant ( database_id );

CREATE TABLE collections_public.table_grant (
 	id uuid PRIMARY KEY DEFAULT ( uuid_generate_v4() ),
	database_id uuid NOT NULL,
	table_id uuid NOT NULL,
	privilege text NOT NULL,
	role_name text NOT NULL,
	field_ids uuid[],
	CONSTRAINT db_fkey FOREIGN KEY ( database_id ) REFERENCES collections_public.database ( id ) ON DELETE CASCADE,
	CONSTRAINT table_fkey FOREIGN KEY ( table_id ) REFERENCES collections_public."table" ( id ) ON DELETE CASCADE,
	UNIQUE ( table_id, privilege, role_name ) 
);

COMMENT ON CONSTRAINT table_fkey ON collections_public.table_grant IS E'@omit manyToMany';

COMMENT ON CONSTRAINT db_fkey ON collections_public.table_grant IS E'@omit manyToMany';

CREATE INDEX table_grant_table_id_idx ON collections_public.table_grant ( table_id );

CREATE INDEX table_grant_database_id_idx ON collections_public.table_grant ( database_id );

CREATE FUNCTION collections_private.table_name_hash ( name text ) RETURNS bytea AS $EOFCODE$
  SELECT
    DECODE(MD5(LOWER(inflection.plural (name))), 'hex');
$EOFCODE$ LANGUAGE sql IMMUTABLE;

CREATE UNIQUE INDEX databases_table_unique_name_idx ON collections_public."table" ( database_id, collections_private.table_name_hash(name) );

CREATE TABLE collections_public.trigger_function (
 	id uuid PRIMARY KEY DEFAULT ( uuid_generate_v4() ),
	database_id uuid NOT NULL,
	name text NOT NULL,
	code text,
	CONSTRAINT db_fkey FOREIGN KEY ( database_id ) REFERENCES collections_public.database ( id ) ON DELETE CASCADE,
	UNIQUE ( database_id, name ) 
);

COMMENT ON CONSTRAINT db_fkey ON collections_public.trigger_function IS E'@omit manyToMany';

CREATE INDEX trigger_function_database_id_idx ON collections_public.trigger_function ( database_id );

CREATE TABLE collections_public.trigger (
 	id uuid PRIMARY KEY DEFAULT ( uuid_generate_v4() ),
	database_id uuid NOT NULL,
	table_id uuid NOT NULL,
	name text NOT NULL,
	event text,
	function_name text,
	CONSTRAINT db_fkey FOREIGN KEY ( database_id ) REFERENCES collections_public.database ( id ) ON DELETE CASCADE,
	CONSTRAINT table_fkey FOREIGN KEY ( table_id ) REFERENCES collections_public."table" ( id ) ON DELETE CASCADE,
	UNIQUE ( table_id, name ) 
);

COMMENT ON CONSTRAINT table_fkey ON collections_public.trigger IS E'@omit manyToMany';

COMMENT ON CONSTRAINT db_fkey ON collections_public.trigger IS E'@omit manyToMany';

CREATE INDEX trigger_table_id_idx ON collections_public.trigger ( table_id );

CREATE INDEX trigger_database_id_idx ON collections_public.trigger ( database_id );

CREATE TABLE collections_public.unique_constraint (
 	id uuid PRIMARY KEY DEFAULT ( uuid_generate_v4() ),
	database_id uuid NOT NULL,
	table_id uuid NOT NULL,
	name text,
	description text,
	smart_tags jsonb,
	type text,
	field_ids uuid[] NOT NULL,
	CONSTRAINT db_fkey FOREIGN KEY ( database_id ) REFERENCES collections_public.database ( id ) ON DELETE CASCADE,
	CONSTRAINT table_fkey FOREIGN KEY ( table_id ) REFERENCES collections_public."table" ( id ) ON DELETE CASCADE,
	UNIQUE ( database_id, name ),
	CHECK ( field_ids <> '{}' ) 
);

COMMENT ON CONSTRAINT table_fkey ON collections_public.unique_constraint IS E'@omit manyToMany';

COMMENT ON CONSTRAINT db_fkey ON collections_public.unique_constraint IS E'@omit manyToMany';

CREATE INDEX unique_constraint_table_id_idx ON collections_public.unique_constraint ( table_id );

CREATE INDEX unique_constraint_database_id_idx ON collections_public.unique_constraint ( database_id );

CREATE SCHEMA meta_private;

GRANT USAGE ON SCHEMA meta_private TO authenticated;

CREATE SCHEMA meta_public;

GRANT USAGE ON SCHEMA meta_public TO authenticated;

CREATE TABLE meta_public.domains (
 	id uuid PRIMARY KEY DEFAULT ( uuid_generate_v4() ),
	database_id uuid NOT NULL REFERENCES collections_public.database ( id ) ON DELETE CASCADE,
	subdomain hostname,
	domain hostname,
	UNIQUE ( subdomain, domain ) 
);

CREATE INDEX domains_database_id_idx ON meta_public.domains ( database_id );

CREATE TABLE meta_public.apis (
 	id uuid PRIMARY KEY DEFAULT ( uuid_generate_v4() ),
	database_id uuid NOT NULL REFERENCES collections_public.database ( id ) ON DELETE CASCADE,
	name text NOT NULL,
	domain_id uuid NOT NULL,
	schemas text[] NOT NULL,
	dbname text NOT NULL DEFAULT ( current_database() ),
	role_name text NOT NULL DEFAULT ( 'authenticated' ),
	anon_role text NOT NULL DEFAULT ( 'anonymous' ),
	is_public boolean NOT NULL DEFAULT ( TRUE ),
	UNIQUE ( database_id, name ),
	UNIQUE ( domain_id ) 
);

ALTER TABLE meta_public.apis ADD CONSTRAINT apis_domain_id_fkey FOREIGN KEY ( domain_id ) REFERENCES meta_public.domains ( id );

COMMENT ON CONSTRAINT apis_domain_id_fkey ON meta_public.apis IS E'@omit manyToMany';

CREATE INDEX apis_domain_id_idx ON meta_public.apis ( domain_id );

CREATE INDEX apis_database_id_idx ON meta_public.apis ( database_id );

CREATE TABLE meta_public.api_extensions (
 	id uuid PRIMARY KEY DEFAULT ( uuid_generate_v4() ),
	name text NOT NULL,
	database_id uuid NOT NULL,
	api_id uuid NOT NULL,
	CONSTRAINT db_fkey FOREIGN KEY ( database_id ) REFERENCES collections_public.database ( id ) ON DELETE CASCADE,
	CONSTRAINT api_fkey FOREIGN KEY ( api_id ) REFERENCES meta_public.apis ( id ) ON DELETE CASCADE,
	UNIQUE ( name, api_id ) 
);

CREATE INDEX api_extension_database_id_idx ON meta_public.api_extensions ( database_id );

CREATE INDEX api_extension_api_id_idx ON meta_public.api_extensions ( api_id );

CREATE TABLE meta_public.api_modules (
 	id uuid PRIMARY KEY DEFAULT ( uuid_generate_v4() ),
	database_id uuid NOT NULL REFERENCES collections_public.database ( id ) ON DELETE CASCADE,
	api_id uuid NOT NULL,
	name text NOT NULL,
	data json NOT NULL 
);

ALTER TABLE meta_public.api_modules ADD CONSTRAINT api_modules_api_id_fkey FOREIGN KEY ( api_id ) REFERENCES meta_public.apis ( id );

COMMENT ON CONSTRAINT api_modules_api_id_fkey ON meta_public.api_modules IS E'@omit manyToMany';

CREATE INDEX api_modules_api_id_idx ON meta_public.api_modules ( api_id );

CREATE INDEX api_modules_database_id_idx ON meta_public.api_modules ( database_id );

CREATE TABLE meta_public.api_schemata (
 	id uuid PRIMARY KEY DEFAULT ( uuid_generate_v4() ),
	database_id uuid NOT NULL,
	schema_id uuid NOT NULL,
	api_id uuid NOT NULL,
	CONSTRAINT db_fkey FOREIGN KEY ( database_id ) REFERENCES collections_public.database ( id ) ON DELETE CASCADE,
	CONSTRAINT schema_fkey FOREIGN KEY ( schema_id ) REFERENCES collections_public.schema ( id ) ON DELETE CASCADE,
	CONSTRAINT api_fkey FOREIGN KEY ( api_id ) REFERENCES meta_public.apis ( id ) ON DELETE CASCADE,
	UNIQUE ( api_id, schema_id ) 
);

COMMENT ON CONSTRAINT db_fkey ON meta_public.api_schemata IS E'@omit manyToMany';

CREATE INDEX api_schemata_database_id_idx ON meta_public.api_schemata ( database_id );

CREATE INDEX api_schemata_schema_id_idx ON meta_public.api_schemata ( schema_id );

CREATE INDEX api_schemata_api_id_idx ON meta_public.api_schemata ( api_id );

CREATE TABLE meta_public.sites (
 	id uuid PRIMARY KEY DEFAULT ( uuid_generate_v4() ),
	database_id uuid NOT NULL REFERENCES collections_public.database ( id ) ON DELETE CASCADE,
	domain_id uuid NOT NULL,
	title text,
	description text,
	og_image image,
	favicon upload,
	apple_touch_icon image,
	logo image,
	dbname text NOT NULL DEFAULT ( current_database() ),
	CHECK ( character_length(title) <= 120 ),
	CHECK ( character_length(description) <= 120 ),
	UNIQUE ( domain_id ) 
);

ALTER TABLE meta_public.sites ADD CONSTRAINT sites_domain_id_fkey FOREIGN KEY ( domain_id ) REFERENCES meta_public.domains ( id );

COMMENT ON CONSTRAINT sites_domain_id_fkey ON meta_public.sites IS E'@omit manyToMany';

CREATE INDEX sites_domain_id_idx ON meta_public.sites ( domain_id );

CREATE INDEX sites_database_id_idx ON meta_public.sites ( database_id );

CREATE TABLE meta_public.apps (
 	id uuid PRIMARY KEY DEFAULT ( uuid_generate_v4() ),
	database_id uuid NOT NULL REFERENCES collections_public.database ( id ) ON DELETE CASCADE,
	site_id uuid NOT NULL,
	name text,
	app_image image,
	app_store_link url,
	app_store_id text,
	app_id_prefix text,
	play_store_link url,
	UNIQUE ( site_id ) 
);

ALTER TABLE meta_public.apps ADD CONSTRAINT apps_site_id_fkey FOREIGN KEY ( site_id ) REFERENCES meta_public.sites ( id );

COMMENT ON CONSTRAINT apps_site_id_fkey ON meta_public.apps IS E'@omit manyToMany';

CREATE INDEX apps_site_id_idx ON meta_public.apps ( site_id );

CREATE INDEX apps_database_id_idx ON meta_public.apps ( database_id );

CREATE TABLE meta_public.site_metadata (
 	id uuid PRIMARY KEY DEFAULT ( uuid_generate_v4() ),
	database_id uuid NOT NULL REFERENCES collections_public.database ( id ) ON DELETE CASCADE,
	site_id uuid NOT NULL,
	title text,
	description text,
	og_image image,
	CHECK ( character_length(title) <= 120 ),
	CHECK ( character_length(description) <= 120 ) 
);

ALTER TABLE meta_public.site_metadata ADD CONSTRAINT site_metadata_site_id_fkey FOREIGN KEY ( site_id ) REFERENCES meta_public.sites ( id );

COMMENT ON CONSTRAINT site_metadata_site_id_fkey ON meta_public.site_metadata IS E'@omit manyToMany';

CREATE INDEX site_metadata_site_id_idx ON meta_public.site_metadata ( site_id );

CREATE INDEX site_metadata_database_id_idx ON meta_public.site_metadata ( database_id );

CREATE TABLE meta_public.site_modules (
 	id uuid PRIMARY KEY DEFAULT ( uuid_generate_v4() ),
	database_id uuid NOT NULL REFERENCES collections_public.database ( id ) ON DELETE CASCADE,
	site_id uuid NOT NULL,
	name text NOT NULL,
	data json NOT NULL 
);

ALTER TABLE meta_public.site_modules ADD CONSTRAINT site_modules_site_id_fkey FOREIGN KEY ( site_id ) REFERENCES meta_public.sites ( id );

COMMENT ON CONSTRAINT site_modules_site_id_fkey ON meta_public.site_modules IS E'@omit manyToMany';

CREATE INDEX site_modules_site_id_idx ON meta_public.site_modules ( site_id );

CREATE INDEX site_modules_database_id_idx ON meta_public.site_modules ( database_id );

CREATE TABLE meta_public.site_themes (
 	id uuid PRIMARY KEY DEFAULT ( uuid_generate_v4() ),
	database_id uuid NOT NULL REFERENCES collections_public.database ( id ) ON DELETE CASCADE,
	site_id uuid NOT NULL,
	theme jsonb NOT NULL 
);

ALTER TABLE meta_public.site_themes ADD CONSTRAINT site_themes_site_id_fkey FOREIGN KEY ( site_id ) REFERENCES meta_public.sites ( id );

COMMENT ON CONSTRAINT site_themes_site_id_fkey ON meta_public.site_themes IS E'@omit manyToMany';

CREATE INDEX site_themes_site_id_idx ON meta_public.site_themes ( site_id );

CREATE INDEX site_themes_database_id_idx ON meta_public.site_themes ( database_id );