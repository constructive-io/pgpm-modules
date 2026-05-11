-- Deploy schemas/metaschema_modules_public/tables/entity_type_provision/table to pg

-- requires: schemas/metaschema_modules_public/schema

BEGIN;

CREATE TABLE metaschema_modules_public.entity_type_provision (
    id uuid PRIMARY KEY DEFAULT uuidv7(),

    database_id uuid NOT NULL,

    -- =========================================================================
    -- Identity: what this membership type is called
    -- =========================================================================

    name text NOT NULL,

    prefix text NOT NULL,

    description text NOT NULL DEFAULT '',

    -- =========================================================================
    -- Parentage: which entity type is the parent (resolved by trigger)
    -- =========================================================================

    parent_entity text NOT NULL DEFAULT 'org',

    -- =========================================================================
    -- Entity table name override
    -- =========================================================================

    table_name text DEFAULT NULL,

    -- =========================================================================
    -- Visibility: can parent members see child entities?
    -- =========================================================================

    is_visible boolean NOT NULL DEFAULT true,

    -- =========================================================================
    -- Optional modules
    -- =========================================================================

    has_limits boolean NOT NULL DEFAULT false,

    has_profiles boolean NOT NULL DEFAULT false,

    has_levels boolean NOT NULL DEFAULT false,

    has_storage boolean NOT NULL DEFAULT false,

    has_invites boolean NOT NULL DEFAULT false,

    -- =========================================================================
    -- Storage configuration: module-level overrides + initial bucket defs.
    -- Only used when has_storage = true. NULL = use defaults.
    -- =========================================================================

    storage_config jsonb DEFAULT NULL,

    -- =========================================================================
    -- Escape hatch: skip default entity table RLS policies
    -- =========================================================================

    skip_entity_policies boolean NOT NULL DEFAULT false,

    -- =========================================================================
    -- Table provisioning override: single jsonb object describing the full
    -- security setup to apply to the entity table, using the same vocabulary
    -- as metaschema_modules_public.provision_table() and blueprint tables[]
    -- entries (policies[], nodes[], fields[], grants[], use_rls).
    --
    -- Semantics:
    --   - NULL (default)        -> apply the 5 default entity-table policies
    --                              (gated by is_visible / skip_entity_policies)
    --   - non-NULL object       -> fan table_provision.policies[] into N
    --                              secure_table_provision rows; the 5 defaults
    --                              are implicitly skipped, and is_visible is
    --                              a no-op on this path.
    -- =========================================================================

    table_provision jsonb DEFAULT NULL,

    -- =========================================================================
    -- Output columns (populated by the trigger, not set by callers)
    -- =========================================================================

    out_membership_type int DEFAULT NULL,

    out_entity_table_id uuid DEFAULT NULL,

    out_entity_table_name text DEFAULT NULL,

    out_installed_modules text[] DEFAULT NULL,

    out_storage_module_id uuid DEFAULT NULL,

    out_buckets_table_id uuid DEFAULT NULL,

    out_files_table_id uuid DEFAULT NULL,

    out_path_shares_table_id uuid DEFAULT NULL,

    out_invites_module_id uuid DEFAULT NULL,

    -- =========================================================================
    -- Constraints
    -- =========================================================================

    CONSTRAINT entity_type_provision_unique_prefix UNIQUE (database_id, prefix),
    CONSTRAINT entity_type_provision_db_fkey FOREIGN KEY (database_id)
        REFERENCES metaschema_public.database (id) ON DELETE CASCADE
);

-- =============================================================================
-- Table-level comment
-- =============================================================================

COMMENT ON TABLE metaschema_modules_public.entity_type_provision IS
    'Provisions a new membership entity type. Each INSERT creates an entity table, registers a membership type,
     and installs the required modules (permissions, memberships, limits) plus optional modules (profiles, levels, invites).
     Uses provision_membership_table() internally. Graceful: duplicate (database_id, prefix) pairs are silently skipped
     via the unique constraint (use INSERT ... ON CONFLICT DO NOTHING).
     Policy behavior: by default the five entity-table RLS policies are applied (gated by is_visible).
     Set table_provision to a single jsonb object (using the same shape as provision_table() /
     blueprint tables[] entries) to replace the defaults with your own; set skip_entity_policies=true
     as an escape hatch to apply zero policies.';

-- =============================================================================
-- Identity columns
-- =============================================================================

COMMENT ON COLUMN metaschema_modules_public.entity_type_provision.id IS
    'Unique identifier for this provision row.';

COMMENT ON COLUMN metaschema_modules_public.entity_type_provision.database_id IS
    'The database to provision this entity type in. Required.';

COMMENT ON COLUMN metaschema_modules_public.entity_type_provision.name IS
    'Human-readable name for this entity type, e.g. ''Data Room'', ''Team Channel''. Required.
     Stored in the entity_types registry table.';

COMMENT ON COLUMN metaschema_modules_public.entity_type_provision.prefix IS
    'SQL prefix used for table and module naming, e.g. ''data_room'', ''team_channel''. Required.
     Drives entity table name (prefix || ''s'' by default), module labels (permissions_module:prefix),
     and membership table names (prefix_memberships, prefix_members, etc.).
     Must be unique per database — the (database_id, prefix) constraint ensures graceful ON CONFLICT DO NOTHING.';

COMMENT ON COLUMN metaschema_modules_public.entity_type_provision.description IS
    'Description of this entity type. Stored in the entity_types registry table. Defaults to empty string.';

-- =============================================================================
-- Parentage
-- =============================================================================

COMMENT ON COLUMN metaschema_modules_public.entity_type_provision.parent_entity IS
    'Prefix of the parent entity type. The trigger resolves this to a membership_type integer
     by looking up memberships_module WHERE prefix = parent_entity.
     Defaults to ''org'' (the organization-level type). For nested types, set to the parent''s prefix
     (e.g. ''data_room'' for a team_channel nested under data_room).
     The parent type must already be provisioned before this INSERT.';

-- =============================================================================
-- Entity table name override
-- =============================================================================

COMMENT ON COLUMN metaschema_modules_public.entity_type_provision.table_name IS
    'Override the entity table name. When NULL (default), the table name is derived as prefix || ''s''
     (e.g. prefix ''data_room'' produces table ''data_rooms'').
     Set this when the pluralization rule doesn''t apply (e.g. prefix ''staff'' should produce ''staff'' not ''staffs'').';

-- =============================================================================
-- Visibility
-- =============================================================================

COMMENT ON COLUMN metaschema_modules_public.entity_type_provision.is_visible IS
    'Whether members of the parent entity can see child entities. Defaults to true.
     When true: a SELECT policy allows parent members to list child entities (e.g. org members can see all data rooms).
     When false: only direct members of the entity itself can see it (private entity mode).
     Controls whether the parent_member SELECT policy is created on the entity table.
     Only meaningful on the defaults path — ignored (no-op) when table_provision is non-NULL or
     skip_entity_policies=true, since no default policies are being applied in those cases.';

-- =============================================================================
-- Optional modules
-- =============================================================================

COMMENT ON COLUMN metaschema_modules_public.entity_type_provision.has_limits IS
    'Whether to apply limits_module security for this type. Defaults to false.
     The limits_module table structure is always created (memberships_module requires it),
     but when false, no RLS policies are applied to the limits tables.
     Set to true if this entity type needs configurable resource limits per membership.';

COMMENT ON COLUMN metaschema_modules_public.entity_type_provision.has_profiles IS
    'Whether to provision profiles_module for this type. Defaults to false.
     Profiles provide named permission roles (e.g. ''Editor'', ''Viewer'') with pre-configured permission bitmasks.
     When true, creates profile tables and applies profiles security.';

COMMENT ON COLUMN metaschema_modules_public.entity_type_provision.has_levels IS
    'Whether to provision levels_module for this type. Defaults to false.
     Levels provide gamification/achievement tracking for members.
     When true, creates level steps, achievements, and level tables with security.';

COMMENT ON COLUMN metaschema_modules_public.entity_type_provision.has_storage IS
    'Whether to provision storage_module for this type. Defaults to false.
     When true, creates {prefix}_buckets and {prefix}_files tables
     with entity-scoped RLS (AuthzEntityMembership) using the entity''s membership_type.
     Storage tables get owner_id FK to the entity table, so files are owned by the entity.';

COMMENT ON COLUMN metaschema_modules_public.entity_type_provision.has_invites IS
    'Whether to provision invites_module for this type. Defaults to false.
     When true, the trigger inserts a row into invites_module which in turn
     (via insert_invites_module BEFORE INSERT) creates {prefix}_invites and
     {prefix}_claimed_invites tables plus the submit_{prefix}_invite_code() function.
     Symmetric counterpart of has_storage. Re-provisioning is idempotent: the
     UNIQUE (database_id, membership_type) constraint on invites_module combined with
     ON CONFLICT DO NOTHING in the fan-out makes repeated INSERTs safe.';

-- =============================================================================
-- Escape hatch
-- =============================================================================

COMMENT ON COLUMN metaschema_modules_public.entity_type_provision.skip_entity_policies IS
    'Escape hatch: when true, apply zero RLS policies to the entity table. Defaults to false.
     Use this only when you want the entity table provisioned with zero policies (e.g. because you
     plan to insert secure_table_provision rows yourself later). In most cases, prefer leaving this
     false and either accepting the five defaults (table_provision=NULL) or overriding them via
     table_provision.
     Defaults (applied when table_provision IS NULL and skip_entity_policies=false):
       - SELECT (parent_member): parent entity members can see child entities (only when is_visible=true)
       - SELECT (self_member):   direct members of the entity can see it
       - INSERT:                 create_entity permission on the parent entity
       - UPDATE:                 admin_entity permission on the entity itself
       - DELETE:                 owner of the entity can delete it';

COMMENT ON COLUMN metaschema_modules_public.entity_type_provision.table_provision IS
    'Single jsonb object describing the full security setup to apply to the entity table.
     Uses the same vocabulary as metaschema_modules_public.provision_table() and blueprint tables[]
     entries, so an entity table is configured the same way an ordinary blueprint table is.
     Defaults to NULL; when non-NULL, the five default policies are implicitly replaced by
     table_provision.policies[] (is_visible becomes a no-op on this path).
     Recognized keys (all optional):
       - use_rls          (boolean, default true)
       - nodes            (jsonb array of {"$type","data"} Data* module entries)
       - fields           (jsonb array of field objects: name,type,is_required,default,min,max,regexp,index)
       - grants           (jsonb array of grant objects; each with roles[] and privileges[])
       - policies         (jsonb array of policy objects; each with $type, privileges, data, name, role, permissive)
     The trigger forwards all setup (nodes/fields/grants/policies) as a single secure_table_provision row
     against the newly created entity table.
     Example — override with two SELECT policies:
       table_provision := jsonb_build_object(
         ''policies'', jsonb_build_array(
           jsonb_build_object(
             ''$type'', ''AuthzEntityMembership'',
             ''privileges'', jsonb_build_array(''select''),
             ''data'', jsonb_build_object(''entity_field'', ''id'', ''membership_type'', 3),
             ''name'', ''self_member''
           ),
           jsonb_build_object(
             ''$type'', ''AuthzDirectOwner'',
             ''privileges'', jsonb_build_array(''select'', ''update''),
             ''data'', jsonb_build_object(''owner_field'', ''owner_id'')
           )
         )
       )';

-- =============================================================================
-- Output columns
-- =============================================================================

COMMENT ON COLUMN metaschema_modules_public.entity_type_provision.out_membership_type IS
    'Output: the auto-assigned integer membership type ID. Populated by the trigger after successful provisioning.
     This is the ID used in entity_types, memberships_module, and all module tables.';

COMMENT ON COLUMN metaschema_modules_public.entity_type_provision.out_entity_table_id IS
    'Output: the UUID of the created entity table. Populated by the trigger.
     Use this to reference the entity table in subsequent relation_provision or secure_table_provision rows.';

COMMENT ON COLUMN metaschema_modules_public.entity_type_provision.out_entity_table_name IS
    'Output: the name of the created entity table (e.g. ''data_rooms''). Populated by the trigger.';

COMMENT ON COLUMN metaschema_modules_public.entity_type_provision.out_installed_modules IS
    'Output: array of installed module labels (e.g. ARRAY[''permissions_module:data_room'', ''memberships_module:data_room'', ''invites_module:data_room'']).
     Populated by the trigger. Useful for verifying which modules were provisioned.';

COMMENT ON COLUMN metaschema_modules_public.entity_type_provision.storage_config IS
    'Optional jsonb object for storage module configuration and initial bucket seeding.
     Only used when has_storage = true; ignored otherwise. NULL = use defaults.
     Recognized keys (all optional):
       - upload_url_expiry_seconds    (integer) presigned PUT URL expiry override
       - download_url_expiry_seconds  (integer) presigned GET URL expiry override
       - default_max_file_size        (bigint)  global max file size in bytes for this scope
       - allowed_origins              (text[])  default CORS origins for all buckets in this scope
       - buckets                      (jsonb[]) array of initial bucket definitions to seed
     Each bucket in the buckets array recognizes:
       - name               (text, required) bucket name e.g. ''documents''
       - description         (text)           human-readable description
       - is_public           (boolean)        whether files are publicly readable (default false)
       - allowed_mime_types  (text[])         whitelist of MIME types (null = any)
       - max_file_size       (bigint)         max file size in bytes (null = use scope default)
       - allowed_origins     (text[])         per-bucket CORS override
       - provisions (jsonb object) optional: customize storage tables
                                  with additional nodes, fields, grants, and policies.
                                  Keyed by table role: "files", "buckets".
                                  Each value uses the same shape as table_provision:
                                  { nodes, fields, grants, use_rls, policies }. Fanned out
                                  to secure_table_provision targeting the corresponding table.
                                  When a key includes policies[], those REPLACE the default
                                  storage policies for that table; tables without a key still
                                  get defaults. Missing "data" on policy entries is auto-populated
                                  with storage-specific defaults (same as table_provision).
                                  Example: add SearchBm25 for full-text search on files:
                                  {"provisions": {"files": {"nodes": [{"$type":
                                  "SearchBm25", "data": {"source_fields": ["description"]}}]}}}
     Example:
       storage_config := ''{"buckets": [{"name": "documents", "is_public": false, "allowed_mime_types": ["application/pdf"]}], "provisions": {"files": {"nodes": [{"$type": "SearchBm25", "data": {"source_fields": ["description"]}}]}}}''::jsonb';

COMMENT ON COLUMN metaschema_modules_public.entity_type_provision.out_storage_module_id IS
    'Output: the UUID of the storage_module row created for this entity type. Populated by the trigger when has_storage=true.';

COMMENT ON COLUMN metaschema_modules_public.entity_type_provision.out_buckets_table_id IS
    'Output: the UUID of the generated buckets table (e.g. data_room_buckets). Populated by the trigger when has_storage=true.';

COMMENT ON COLUMN metaschema_modules_public.entity_type_provision.out_files_table_id IS
    'Output: the UUID of the generated files table (e.g. data_room_files). Populated by the trigger when has_storage=true.';

COMMENT ON COLUMN metaschema_modules_public.entity_type_provision.out_invites_module_id IS
    'Output: the UUID of the invites_module row created for this entity type. Populated by the trigger when has_invites=true.
     NULL when has_invites=false, or when re-provisioning hits ON CONFLICT DO NOTHING
     (i.e. the invites_module row was created in a previous run).';

COMMIT;
