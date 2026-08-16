-- Deploy schemas/metaschema_modules_public/tables/pages_module/table to pg

-- requires: schemas/metaschema_modules_public/schema
-- requires: schemas/metaschema_modules_public/tables/merkle_store_module/table
-- requires: schemas/metaschema_modules_public/tables/site_surface_module/table

BEGIN;

CREATE TABLE metaschema_modules_public.pages_module (
    id uuid PRIMARY KEY DEFAULT uuidv7(),
    database_id uuid NOT NULL,
    public_schema_id uuid NOT NULL DEFAULT uuid_nil(),
    private_schema_id uuid NOT NULL DEFAULT uuid_nil(),
    public_schema_name text,
    private_schema_name text,
    scope text NOT NULL,
    prefix text NOT NULL,

    -- Backing merkle store (reused, never a new store per the pages spec)
    merkle_store_module_id uuid NOT NULL,

    -- Site surface whose sites table the pages head FKs into (resolved from the
    -- same-database/scope site_surface_module by the insert trigger when NULL).
    site_surface_module_id uuid,
    -- Resolved sites table id (site_id FK target), populated by the trigger.
    sites_table_id uuid NOT NULL DEFAULT uuid_nil(),

    -- Generated head table id (populated by the generator)
    pages_table_id uuid NOT NULL DEFAULT uuid_nil(),

    -- Per-site store-row name prefix inside the reused Merkle store tables:
    -- the actual store name is <store_name_prefix> || site_id (one store per
    -- site). The store holds ALL of the site's versioned content — pages,
    -- metadata, themes — so it is named for the site, not for pages.
    store_name_prefix text NOT NULL DEFAULT 'site:',

    api_name text,
    private_api_name text,
    entity_table_id uuid NULL,
    policies jsonb NULL,
    provisions jsonb NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pages_module_db_fkey FOREIGN KEY (database_id) REFERENCES metaschema_public.database (id) ON DELETE CASCADE,
    CONSTRAINT pages_module_public_schema_fkey FOREIGN KEY (public_schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
    CONSTRAINT pages_module_private_schema_fkey FOREIGN KEY (private_schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
    CONSTRAINT pages_module_merkle_store_fkey FOREIGN KEY (merkle_store_module_id) REFERENCES metaschema_modules_public.merkle_store_module (id) ON DELETE CASCADE,
    CONSTRAINT pages_module_site_surface_fkey FOREIGN KEY (site_surface_module_id) REFERENCES metaschema_modules_public.site_surface_module (id) ON DELETE CASCADE,
    CONSTRAINT pages_module_sites_table_fkey FOREIGN KEY (sites_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT pages_module_pages_table_fkey FOREIGN KEY (pages_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT pages_module_entity_table_fkey FOREIGN KEY (entity_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT pages_module_database_scope_unique UNIQUE (database_id, scope)
);

CREATE INDEX pages_module_entity_table_id_idx ON metaschema_modules_public.pages_module ( entity_table_id );
CREATE INDEX pages_module_pages_table_id_idx ON metaschema_modules_public.pages_module ( pages_table_id );
CREATE INDEX pages_module_sites_table_id_idx ON metaschema_modules_public.pages_module ( sites_table_id );
CREATE INDEX pages_module_site_surface_module_id_idx ON metaschema_modules_public.pages_module ( site_surface_module_id );
CREATE INDEX pages_module_private_schema_id_idx ON metaschema_modules_public.pages_module ( private_schema_id );
CREATE INDEX pages_module_public_schema_id_idx ON metaschema_modules_public.pages_module ( public_schema_id );
CREATE INDEX pages_module_merkle_store_module_id_idx ON metaschema_modules_public.pages_module ( merkle_store_module_id );

-- Tables this module generates, as opposed to tables it is handed (an
-- entity or users table it points at): the @module_table marker is what
-- metaschema_modules_private.tg_module_install_provenance attributes to this
-- install, keyed by the role name in the column.
COMMENT ON COLUMN metaschema_modules_public.pages_module.pages_table_id IS '@module_table';

COMMIT;
