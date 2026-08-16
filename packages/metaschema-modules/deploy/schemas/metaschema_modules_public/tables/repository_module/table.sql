-- Deploy schemas/metaschema_modules_public/tables/repository_module/table to pg

-- requires: schemas/metaschema_modules_public/schema

BEGIN;

CREATE TABLE metaschema_modules_public.repository_module (
    id uuid PRIMARY KEY DEFAULT uuidv7(),
    database_id uuid NOT NULL,

    -- Scope-key column name on the generated table(s), recorded by the insert
    -- trigger via metaschema_generators.scope_key_column(scope, key): database ->
    -- 'database_id', entity -> the module's key ('entity_id' here), global -> NULL.
    entity_field text,

    -- Schema references (if uuid_nil, resolved from schema name or default)
    schema_id uuid NOT NULL DEFAULT uuid_nil(),
    private_schema_id uuid NOT NULL DEFAULT uuid_nil(),

    -- Optional schema name overrides (used when schema IDs are not provided)
    public_schema_name text,
    private_schema_name text,

    -- Generated table IDs (populated by the generator)
    repositories_table_id uuid NOT NULL DEFAULT uuid_nil(),
    repository_events_table_id uuid NOT NULL DEFAULT uuid_nil(),
    workflows_table_id uuid NOT NULL DEFAULT uuid_nil(),
    builds_table_id uuid NOT NULL DEFAULT uuid_nil(),
    build_steps_table_id uuid NOT NULL DEFAULT uuid_nil(),
    change_requests_table_id uuid NOT NULL DEFAULT uuid_nil(),
    change_request_comments_table_id uuid NOT NULL DEFAULT uuid_nil(),
    change_request_reactions_table_id uuid NOT NULL DEFAULT uuid_nil(),
    change_request_reviews_table_id uuid NOT NULL DEFAULT uuid_nil(),
    change_request_file_views_table_id uuid NOT NULL DEFAULT uuid_nil(),

    -- Table names (input to the generator)
    repositories_table_name text NOT NULL DEFAULT 'repositories',
    repository_events_table_name text NOT NULL DEFAULT 'repository_events',
    workflows_table_name text NOT NULL DEFAULT 'repository_workflows',
    builds_table_name text NOT NULL DEFAULT 'builds',
    build_steps_table_name text NOT NULL DEFAULT 'build_steps',
    change_requests_table_name text NOT NULL DEFAULT 'change_requests',
    change_request_comments_table_name text NOT NULL DEFAULT 'change_request_comments',
    change_request_reactions_table_name text NOT NULL DEFAULT 'change_request_reactions',
    change_request_reviews_table_name text NOT NULL DEFAULT 'change_request_reviews',
    change_request_file_views_table_name text NOT NULL DEFAULT 'change_request_file_views',

    -- Workflows and builds enqueue jobs that run flow graphs, so they are only
    -- coherent at a scope that has a compute plane; an install without one gets
    -- the repository, event and review surface and nothing that needs a runner.
    has_builds boolean NOT NULL DEFAULT false,

    -- Images and files in a review comment, stored by the storage module at this
    -- same scope. Off by default because turning it on requires that module:
    -- provisioning raises rather than accepting a file it has nowhere to put.
    has_attachments boolean NOT NULL DEFAULT false,

    -- API routing (get-or-create: if set, schema is added to this API; if NULL, no API is added)
    api_name text,
    private_api_name text,

    -- Scope: determines the security level for this module instance.
    scope text NOT NULL,

    -- Table name prefix. Auto-derived from scope by the trigger when empty.
    prefix text NOT NULL DEFAULT '',

    -- Entity table for RLS (NULL for global scopes, entity table for entity scopes)
    entity_table_id uuid NULL,

    -- Configurable security policies (NULL = use defaults based on scope).
    policies jsonb NULL,

    -- Per-table provisions overrides from blueprint config. Keys are table keys
    -- (repositories, repository_events, workflows, builds, build_steps,
    -- change_requests, change_request_comments, change_request_reactions,
    -- change_request_reviews, change_request_file_views).
    provisions jsonb NULL,

    -- Default capabilities: capability names auto-granted to new members.
    default_capabilities text[] DEFAULT NULL,

    CONSTRAINT repository_module_db_fkey FOREIGN KEY (database_id) REFERENCES metaschema_public.database (id) ON DELETE CASCADE,
    CONSTRAINT repository_module_schema_fkey FOREIGN KEY (schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
    CONSTRAINT repository_module_private_schema_fkey FOREIGN KEY (private_schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
    CONSTRAINT repository_module_repositories_table_fkey FOREIGN KEY (repositories_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT repository_module_events_table_fkey FOREIGN KEY (repository_events_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT repository_module_workflows_table_fkey FOREIGN KEY (workflows_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT repository_module_builds_table_fkey FOREIGN KEY (builds_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT repository_module_build_steps_table_fkey FOREIGN KEY (build_steps_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT repository_module_change_requests_table_fkey FOREIGN KEY (change_requests_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT repository_module_comments_table_fkey FOREIGN KEY (change_request_comments_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT repository_module_reactions_table_fkey FOREIGN KEY (change_request_reactions_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT repository_module_reviews_table_fkey FOREIGN KEY (change_request_reviews_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT repository_module_file_views_table_fkey FOREIGN KEY (change_request_file_views_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT repository_module_entity_table_fkey FOREIGN KEY (entity_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE
);

-- One repository module per database per scope: repository slugs are unique
-- within the scope that owns them, so a second install at the same scope would
-- make a clone URL ambiguous.
CREATE UNIQUE INDEX repository_module_unique_scope ON metaschema_modules_public.repository_module ( database_id, scope );
CREATE INDEX repository_module_entity_table_id_idx ON metaschema_modules_public.repository_module ( entity_table_id );
CREATE INDEX repository_module_repositories_table_id_idx ON metaschema_modules_public.repository_module ( repositories_table_id );
CREATE INDEX repository_module_repository_events_table_id_idx ON metaschema_modules_public.repository_module ( repository_events_table_id );
CREATE INDEX repository_module_workflows_table_id_idx ON metaschema_modules_public.repository_module ( workflows_table_id );
CREATE INDEX repository_module_builds_table_id_idx ON metaschema_modules_public.repository_module ( builds_table_id );
CREATE INDEX repository_module_build_steps_table_id_idx ON metaschema_modules_public.repository_module ( build_steps_table_id );
CREATE INDEX repository_module_change_requests_table_id_idx ON metaschema_modules_public.repository_module ( change_requests_table_id );
CREATE INDEX repository_module_comments_table_id_idx ON metaschema_modules_public.repository_module ( change_request_comments_table_id );
CREATE INDEX repository_module_reactions_table_id_idx ON metaschema_modules_public.repository_module ( change_request_reactions_table_id );
CREATE INDEX repository_module_reviews_table_id_idx ON metaschema_modules_public.repository_module ( change_request_reviews_table_id );
CREATE INDEX repository_module_file_views_table_id_idx ON metaschema_modules_public.repository_module ( change_request_file_views_table_id );
CREATE INDEX repository_module_private_schema_id_idx ON metaschema_modules_public.repository_module ( private_schema_id );
CREATE INDEX repository_module_schema_id_idx ON metaschema_modules_public.repository_module ( schema_id );

-- Tables this module generates, as opposed to tables it is handed (an entity or
-- graph table it points at): the @module_table marker is what
-- metaschema_modules_private.tg_module_install_provenance attributes to this
-- install, keyed by the role name in the column.
COMMENT ON COLUMN metaschema_modules_public.repository_module.repositories_table_id IS '@module_table';
COMMENT ON COLUMN metaschema_modules_public.repository_module.repository_events_table_id IS '@module_table';
COMMENT ON COLUMN metaschema_modules_public.repository_module.workflows_table_id IS '@module_table';
COMMENT ON COLUMN metaschema_modules_public.repository_module.builds_table_id IS '@module_table';
COMMENT ON COLUMN metaschema_modules_public.repository_module.build_steps_table_id IS '@module_table';
COMMENT ON COLUMN metaschema_modules_public.repository_module.change_requests_table_id IS '@module_table';
COMMENT ON COLUMN metaschema_modules_public.repository_module.change_request_comments_table_id IS '@module_table';
COMMENT ON COLUMN metaschema_modules_public.repository_module.change_request_reactions_table_id IS '@module_table';
COMMENT ON COLUMN metaschema_modules_public.repository_module.change_request_reviews_table_id IS '@module_table';
COMMENT ON COLUMN metaschema_modules_public.repository_module.change_request_file_views_table_id IS '@module_table';

COMMIT;
