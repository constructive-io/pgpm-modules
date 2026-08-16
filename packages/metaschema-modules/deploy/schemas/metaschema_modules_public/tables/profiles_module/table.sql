-- Deploy schemas/metaschema_modules_public/tables/profiles_module/table to pg

-- requires: schemas/metaschema_modules_public/schema

BEGIN;

CREATE TABLE metaschema_modules_public.profiles_module (
    id uuid PRIMARY KEY DEFAULT uuidv7(),
    database_id uuid NOT NULL,

    -- Scope-key column name on the generated table(s), recorded by the insert
    -- trigger via metaschema_generators.scope_key_column(scope, key): database ->
    -- 'database_id', entity -> the module's key ('entity_id' here), global -> NULL.
    entity_field text,
    --
    schema_id uuid NOT NULL DEFAULT uuid_nil(),
    private_schema_id uuid NOT NULL DEFAULT uuid_nil(),

  -- Schema name overrides: when set, the trigger uses these instead of hardcoded defaults.
  public_schema_name text,
  private_schema_name text,
    
    -- Main profiles table
    table_id uuid NOT NULL DEFAULT uuid_nil(),
    table_name text NOT NULL DEFAULT '',
    
    -- Profile capabilities join table (for UI)
    profile_capabilities_table_id uuid NOT NULL DEFAULT uuid_nil(),
    profile_capabilities_table_name text NOT NULL DEFAULT '',
    
    -- Profile grants audit table
    profile_grants_table_id uuid NOT NULL DEFAULT uuid_nil(),
    profile_grants_table_name text NOT NULL DEFAULT '',
    
    -- Profile definition grants audit table
    profile_definition_grants_table_id uuid NOT NULL DEFAULT uuid_nil(),
    profile_definition_grants_table_name text NOT NULL DEFAULT '',

    -- Profile assignment set: every profile a membership holds, and the only
    -- profile-derived authorization input. memberships.profile_id is a pointer at
    -- one of its rows, kept in sync by the generated triggers.
    membership_profiles_table_id uuid NOT NULL DEFAULT uuid_nil(),
    membership_profiles_table_name text NOT NULL DEFAULT '',

    -- Profile templates table (for seeding profiles into new entities)
    profile_templates_table_id uuid NOT NULL DEFAULT uuid_nil(),
    profile_templates_table_name text NOT NULL DEFAULT '',
    
    -- Scope: determines the security level for this module instance.
    scope text NOT NULL,

    -- Table name prefix. Auto-derived from scope by the trigger when empty.
    prefix text NOT NULL DEFAULT '',
    
    -- Entity table for org/group scoped profiles (NULL for app-level)
    entity_table_id uuid NULL,
    
    -- Required tables
    actor_table_id uuid NOT NULL DEFAULT uuid_nil(),
    capabilities_table_id uuid NOT NULL DEFAULT uuid_nil(),
    memberships_table_id uuid NOT NULL DEFAULT uuid_nil(),
    
    -- API routing (configurable per-module)
    api_name text DEFAULT 'admin',
    private_api_name text DEFAULT NULL,

    --
    CONSTRAINT db_fkey FOREIGN KEY (database_id) REFERENCES metaschema_public.database (id) ON DELETE CASCADE,
    CONSTRAINT schema_fkey FOREIGN KEY (schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
    CONSTRAINT private_schema_fkey FOREIGN KEY (private_schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
    CONSTRAINT table_fkey FOREIGN KEY (table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT profile_capabilities_table_fkey FOREIGN KEY (profile_capabilities_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT profile_grants_table_fkey FOREIGN KEY (profile_grants_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT profile_definition_grants_table_fkey FOREIGN KEY (profile_definition_grants_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT membership_profiles_table_fkey FOREIGN KEY (membership_profiles_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT profile_templates_table_fkey FOREIGN KEY (profile_templates_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT entity_table_fkey FOREIGN KEY (entity_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT actor_table_fkey FOREIGN KEY (actor_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT capabilities_table_fkey FOREIGN KEY (capabilities_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT memberships_table_fkey FOREIGN KEY (memberships_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    
    CONSTRAINT profiles_module_unique UNIQUE (database_id, scope, prefix)
);

CREATE INDEX profiles_module_actor_table_id_idx ON metaschema_modules_public.profiles_module ( actor_table_id );
CREATE INDEX profiles_module_entity_table_id_idx ON metaschema_modules_public.profiles_module ( entity_table_id );
CREATE INDEX profiles_module_memberships_table_id_idx ON metaschema_modules_public.profiles_module ( memberships_table_id );
CREATE INDEX profiles_module_capabilities_table_id_idx ON metaschema_modules_public.profiles_module ( capabilities_table_id );
CREATE INDEX profiles_module_profile_definition_grants_table_id_idx ON metaschema_modules_public.profiles_module ( profile_definition_grants_table_id );
CREATE INDEX profiles_module_profile_grants_table_id_idx ON metaschema_modules_public.profiles_module ( profile_grants_table_id );
CREATE INDEX profiles_module_profile_capabilities_table_id_idx ON metaschema_modules_public.profiles_module ( profile_capabilities_table_id );
CREATE INDEX profiles_module_profile_templates_table_id_idx ON metaschema_modules_public.profiles_module ( profile_templates_table_id );
CREATE INDEX profiles_module_membership_profiles_table_id_idx ON metaschema_modules_public.profiles_module ( membership_profiles_table_id );
CREATE INDEX profiles_module_table_id_idx ON metaschema_modules_public.profiles_module ( table_id );
CREATE INDEX profiles_module_private_schema_id_idx ON metaschema_modules_public.profiles_module ( private_schema_id );
CREATE INDEX profiles_module_schema_id_idx ON metaschema_modules_public.profiles_module ( schema_id );

-- Tables this module generates, as opposed to tables it is handed (an
-- entity or users table it points at): the @module_table marker is what
-- metaschema_modules_private.tg_module_install_provenance attributes to this
-- install, keyed by the role name in the column.
COMMENT ON COLUMN metaschema_modules_public.profiles_module.membership_profiles_table_id IS '@module_table';
COMMENT ON COLUMN metaschema_modules_public.profiles_module.profile_capabilities_table_id IS '@module_table';
COMMENT ON COLUMN metaschema_modules_public.profiles_module.profile_definition_grants_table_id IS '@module_table';
COMMENT ON COLUMN metaschema_modules_public.profiles_module.profile_grants_table_id IS '@module_table';
COMMENT ON COLUMN metaschema_modules_public.profiles_module.profile_templates_table_id IS '@module_table';
COMMENT ON COLUMN metaschema_modules_public.profiles_module.table_id IS '@module_table';

COMMIT;
