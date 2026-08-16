-- Deploy schemas/metaschema_modules_public/tables/k8s_admission_module/table to pg

-- requires: schemas/metaschema_modules_public/schema
-- requires: schemas/metaschema_modules_public/tables/merkle_store_module/table

BEGIN;

CREATE TABLE metaschema_modules_public.k8s_admission_module (
    id uuid PRIMARY KEY DEFAULT uuidv7(),
    database_id uuid NOT NULL,
    public_schema_id uuid NOT NULL DEFAULT uuid_nil(),
    private_schema_id uuid NOT NULL DEFAULT uuid_nil(),
    public_schema_name text,
    private_schema_name text,
    scope text NOT NULL,
    prefix text NOT NULL,
    merkle_store_module_id uuid NOT NULL,
    k8s_resource_kinds_table_id uuid NOT NULL DEFAULT uuid_nil(),
    k8s_spec_rules_table_id uuid NOT NULL DEFAULT uuid_nil(),

    -- Store row name inside the Merkle store tables (one shared infra store)
    store_name text NOT NULL,

    api_name text,
    private_api_name text,
    entity_table_id uuid NULL,
    policies jsonb NULL,
    provisions jsonb NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT db_fkey FOREIGN KEY (database_id) REFERENCES metaschema_public.database (id) ON DELETE CASCADE,
    CONSTRAINT public_schema_fkey FOREIGN KEY (public_schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
    CONSTRAINT private_schema_fkey FOREIGN KEY (private_schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,
    CONSTRAINT merkle_store_fkey FOREIGN KEY (merkle_store_module_id) REFERENCES metaschema_modules_public.merkle_store_module (id) ON DELETE CASCADE,
    CONSTRAINT k8s_resource_kinds_table_fkey FOREIGN KEY (k8s_resource_kinds_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT k8s_spec_rules_table_fkey FOREIGN KEY (k8s_spec_rules_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT k8s_admission_module_entity_table_fkey FOREIGN KEY (entity_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
    CONSTRAINT k8s_admission_module_database_merkle_unique UNIQUE (database_id, merkle_store_module_id)
);

CREATE INDEX k8s_admission_module_entity_table_id_idx ON metaschema_modules_public.k8s_admission_module ( entity_table_id );
CREATE INDEX k8s_admission_module_k8s_resource_kinds_table_id_idx ON metaschema_modules_public.k8s_admission_module ( k8s_resource_kinds_table_id );
CREATE INDEX k8s_admission_module_k8s_spec_rules_table_id_idx ON metaschema_modules_public.k8s_admission_module ( k8s_spec_rules_table_id );
CREATE INDEX k8s_admission_module_private_schema_id_idx ON metaschema_modules_public.k8s_admission_module ( private_schema_id );
CREATE INDEX k8s_admission_module_public_schema_id_idx ON metaschema_modules_public.k8s_admission_module ( public_schema_id );
CREATE INDEX k8s_admission_module_merkle_store_module_id_idx ON metaschema_modules_public.k8s_admission_module ( merkle_store_module_id );

COMMENT ON TABLE metaschema_modules_public.k8s_admission_module IS 'Provisions the platform-managed Kubernetes admission catalogs: a kinds table and a spec-rules table, Merkle-versioned through the referenced merkle_store_module, whose rows the generated admission gate on resources/resource_definitions reads. Writes are platform-admin and human-only; every scope reads the one catalog.';

-- Tables this module generates, as opposed to tables it is handed (the entity
-- table it points at): the @module_table marker is what
-- metaschema_modules_private.tg_module_install_provenance attributes to this
-- install, keyed by the role name in the column.
COMMENT ON COLUMN metaschema_modules_public.k8s_admission_module.k8s_resource_kinds_table_id IS '@module_table';
COMMENT ON COLUMN metaschema_modules_public.k8s_admission_module.k8s_spec_rules_table_id IS '@module_table';

COMMIT;
