\echo Use "CREATE EXTENSION launchql-db_meta_test" to load this file. \quit
DO $EOFCODE$
  DECLARE
    owner_id uuid = '07281002-1699-4762-57e3-ab1b92243120';
    database_id uuid;
    schema_id uuid;
    private_schema_id uuid;
    table_id uuid;
    site_id uuid;
    api_id uuid;
    meta_api_id uuid;
  BEGIN

    INSERT INTO collections_public.database (owner_id, name)
      VALUES (owner_id, 'meta_db')
    RETURNING id INTO database_id;

    INSERT INTO collections_public.schema (database_id, name, schema_name)
      VALUES (database_id, 'public', 'public_schema')
    RETURNING id INTO schema_id;

    INSERT INTO collections_public.schema (database_id, name, schema_name)
      VALUES (database_id, 'private', 'private_schema')
    RETURNING id INTO private_schema_id;
 
    INSERT INTO collections_public.table (database_id, schema_id, name)
      VALUES (database_id, schema_id, 'mytable')
    RETURNING id INTO table_id;

    INSERT INTO meta_public.apis (database_id, name)
      VALUES 
        (database_id, 'public')
    RETURNING id INTO api_id;

    INSERT INTO meta_public.apis (database_id, name)
      VALUES 
        (database_id, 'meta')
    RETURNING id INTO meta_api_id;

    INSERT INTO meta_public.sites (database_id, title, description)
      VALUES 
        (database_id, 'Title', 'Description goes here')
    RETURNING id INTO site_id;

    INSERT INTO meta_public.apps (database_id, site_id, name)
      VALUES 
        (database_id, site_id, 'My App');

    INSERT INTO meta_public.domains (database_id, api_id, site_id, subdomain, domain)
      VALUES
    (database_id, api_id, NULL, 'api', 'lql.io'),
    (database_id, NULL, site_id, 'app', 'lql.io'),
    (database_id, meta_api_id, NULL, 'meta', 'lql.io');

    -- add schemas

    INSERT INTO meta_public.api_schemata (database_id, schema_id, api_id)
      VALUES 
    (database_id, schema_id, api_id);

    INSERT INTO meta_public.api_extensions (database_id, schema_name, api_id)
      VALUES 
    (database_id, 'collections_public', meta_api_id),
    (database_id, 'meta_public', meta_api_id);

    -- add site info

    INSERT INTO meta_public.site_metadata (database_id, site_id, title)
      VALUES
    (database_id, site_id, 'SEO-able title');

    INSERT INTO meta_public.site_themes (database_id, site_id, theme)
      VALUES
    (database_id, site_id, '{"primaryColor":"#aeaeae"}');

    -- add some modules

    INSERT INTO meta_public.user_auth_module (database_id, schema_id, emails_table_id, users_table_id, secrets_table_id, encrypted_table_id, tokens_table_id)
      VALUES
    (database_id, schema_id, table_id, table_id, table_id, table_id, table_id );

    INSERT INTO meta_public.rls_module (database_id, api_id, schema_id, private_schema_id, tokens_table_id, users_table_id)
      VALUES
    (database_id, api_id, schema_id, private_schema_id, table_id, table_id );

  END;
$EOFCODE$;