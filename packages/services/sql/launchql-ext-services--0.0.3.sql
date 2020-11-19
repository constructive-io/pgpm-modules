\echo Use "CREATE EXTENSION launchql-ext-services" to load this file. \quit
CREATE SCHEMA services_public;

CREATE TABLE services_public.services (
 	id uuid PRIMARY KEY DEFAULT ( uuid_generate_v4() ),
	database_id uuid,
	is_public bool,
	type text,
	name text,
	subdomain citext,
	domain citext,
	dbname text,
	role_name text,
	anon_role text,
	schemas text[],
	auth text[],
	pubkey_challenge text[],
	UNIQUE ( subdomain, domain ) 
);