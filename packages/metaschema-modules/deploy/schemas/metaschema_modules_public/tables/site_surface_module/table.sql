-- Deploy schemas/metaschema_modules_public/tables/site_surface_module/table to pg

-- requires: schemas/metaschema_modules_public/schema
-- requires: schemas/metaschema_modules_public/tables/catalog_module/table

BEGIN;

CREATE TABLE metaschema_modules_public.site_surface_module (
    id uuid PRIMARY KEY DEFAULT uuidv7(),
    database_id uuid NOT NULL,

    -- Scope-key column name on the generated table, recorded by the insert
    -- trigger via metaschema_generators.scope_key_column(scope, key).
    entity_field text,

    -- Schema reference (if uuid_nil, resolved from schema name or default)
    schema_id uuid NOT NULL DEFAULT uuid_nil(),
    -- Private schema hosting the backing seam-guard trigger function.
    private_schema_id uuid NOT NULL DEFAULT uuid_nil(),

    -- Optional schema name overrides (used when the ids are not provided)
    public_schema_name text,
    private_schema_name text,

    -- Catalog the sites register their owner-qualified identity into.
    -- Resolved by the insert trigger from the same-database catalog_module
    -- when NULL.
    catalog_module_id uuid,

    -- Generated table IDs (populated by the generator)
    sites_table_id uuid NOT NULL DEFAULT uuid_nil(),
    site_metadata_table_id uuid NOT NULL DEFAULT uuid_nil(),
    site_modules_table_id uuid NOT NULL DEFAULT uuid_nil(),
    site_themes_table_id uuid NOT NULL DEFAULT uuid_nil(),
    site_app_links_table_id uuid NOT NULL DEFAULT uuid_nil(),
    site_deep_links_table_id uuid NOT NULL DEFAULT uuid_nil(),
    -- Serving-config companions (the distribution tier's typed behavior):
    -- site_web_config (1:1) + site_error_pages (1:N). Always generated — a
    -- site IS the distribution, so it always owns its serving configuration.
    site_web_config_table_id uuid NOT NULL DEFAULT uuid_nil(),
    site_error_pages_table_id uuid NOT NULL DEFAULT uuid_nil(),

    -- Table names (input to the generator)
    sites_table_name text NOT NULL DEFAULT 'sites',
    site_metadata_table_name text NOT NULL DEFAULT 'site_metadata',
    site_modules_table_name text NOT NULL DEFAULT 'site_modules',
    site_themes_table_name text NOT NULL DEFAULT 'site_themes',
    site_app_links_table_name text NOT NULL DEFAULT 'site_app_links',
    site_deep_links_table_name text NOT NULL DEFAULT 'site_deep_links',
    site_web_config_table_name text NOT NULL DEFAULT 'site_web_config',
    site_error_pages_table_name text NOT NULL DEFAULT 'site_error_pages',

    -- API routing (get-or-create: if set, schema is added to this API)
    api_name text,
    private_api_name text,

    -- Scope: determines the security level for this module instance.
    scope text NOT NULL,

    -- Table name prefix. Auto-derived from scope by the trigger when empty.
    prefix text NOT NULL DEFAULT '',

    -- Entity table for RLS (NULL for non-entity scopes)
    entity_table_id uuid NULL,

    -- Configurable security policies (NULL = use defaults based on scope)
    policies jsonb NULL,

    -- Per-table provisions overrides from blueprint config
    provisions jsonb NULL,

    -- Default capabilities: capability names auto-granted to new members
    default_capabilities text[] DEFAULT NULL,

    CONSTRAINT site_module_db_fkey
        FOREIGN KEY (database_id)
        REFERENCES metaschema_public.database (id)
        ON DELETE CASCADE,
    CONSTRAINT site_module_schema_fkey
        FOREIGN KEY (schema_id)
        REFERENCES metaschema_public.schema (id)
        ON DELETE CASCADE,
    CONSTRAINT site_module_private_schema_fkey
        FOREIGN KEY (private_schema_id)
        REFERENCES metaschema_public.schema (id)
        ON DELETE CASCADE,
    CONSTRAINT site_module_catalog_fkey
        FOREIGN KEY (catalog_module_id)
        REFERENCES metaschema_modules_public.catalog_module (id)
        ON DELETE CASCADE,
    CONSTRAINT site_module_sites_table_fkey
        FOREIGN KEY (sites_table_id)
        REFERENCES metaschema_public.table (id)
        ON DELETE CASCADE,
    CONSTRAINT site_module_site_metadata_table_fkey
        FOREIGN KEY (site_metadata_table_id)
        REFERENCES metaschema_public.table (id)
        ON DELETE CASCADE,
    CONSTRAINT site_module_site_modules_table_fkey
        FOREIGN KEY (site_modules_table_id)
        REFERENCES metaschema_public.table (id)
        ON DELETE CASCADE,
    CONSTRAINT site_module_site_themes_table_fkey
        FOREIGN KEY (site_themes_table_id)
        REFERENCES metaschema_public.table (id)
        ON DELETE CASCADE,
    CONSTRAINT site_module_site_app_links_table_fkey
        FOREIGN KEY (site_app_links_table_id)
        REFERENCES metaschema_public.table (id)
        ON DELETE CASCADE,
    CONSTRAINT site_module_site_deep_links_table_fkey
        FOREIGN KEY (site_deep_links_table_id)
        REFERENCES metaschema_public.table (id)
        ON DELETE CASCADE,
    CONSTRAINT site_module_site_web_config_table_fkey
        FOREIGN KEY (site_web_config_table_id)
        REFERENCES metaschema_public.table (id)
        ON DELETE CASCADE,
    CONSTRAINT site_module_site_error_pages_table_fkey
        FOREIGN KEY (site_error_pages_table_id)
        REFERENCES metaschema_public.table (id)
        ON DELETE CASCADE,
    CONSTRAINT site_module_entity_table_fkey
        FOREIGN KEY (entity_table_id)
        REFERENCES metaschema_public.table (id)
        ON DELETE CASCADE
);

CREATE UNIQUE INDEX site_module_unique_scope
    ON metaschema_modules_public.site_surface_module (database_id, scope);
CREATE INDEX site_surface_module_entity_table_id_idx ON metaschema_modules_public.site_surface_module ( entity_table_id );
CREATE INDEX site_surface_module_site_metadata_table_id_idx ON metaschema_modules_public.site_surface_module ( site_metadata_table_id );
CREATE INDEX site_surface_module_site_modules_table_id_idx ON metaschema_modules_public.site_surface_module ( site_modules_table_id );
CREATE INDEX site_surface_module_site_themes_table_id_idx ON metaschema_modules_public.site_surface_module ( site_themes_table_id );
CREATE INDEX site_surface_module_site_app_links_table_id_idx ON metaschema_modules_public.site_surface_module ( site_app_links_table_id );
CREATE INDEX site_surface_module_site_deep_links_table_id_idx ON metaschema_modules_public.site_surface_module ( site_deep_links_table_id );
CREATE INDEX site_surface_module_site_web_config_table_id_idx ON metaschema_modules_public.site_surface_module ( site_web_config_table_id );
CREATE INDEX site_surface_module_site_error_pages_table_id_idx ON metaschema_modules_public.site_surface_module ( site_error_pages_table_id );
CREATE INDEX site_surface_module_sites_table_id_idx ON metaschema_modules_public.site_surface_module ( sites_table_id );
CREATE INDEX site_surface_module_schema_id_idx ON metaschema_modules_public.site_surface_module ( schema_id );
CREATE INDEX site_surface_module_catalog_module_id_idx ON metaschema_modules_public.site_surface_module ( catalog_module_id );

COMMIT;
