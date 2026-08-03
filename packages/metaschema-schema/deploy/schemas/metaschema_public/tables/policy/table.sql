-- Deploy schemas/metaschema_public/tables/policy/table to pg

-- requires: schemas/metaschema_public/schema
-- requires: schemas/metaschema_public/tables/table/table
-- requires: schemas/metaschema_public/types/object_category

BEGIN;

CREATE TABLE metaschema_public.policy (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  database_id uuid NOT NULL DEFAULT uuid_nil(),

  table_id uuid NOT NULL,
  name text,
  grantee_name text,
  privilege text,

  -- using_expression text,
  -- check_expression text,
  -- policy_text text,

  permissive boolean default true,
  disabled boolean default false,

  policy_type text,
  data jsonb,

  with_check jsonb,

  smart_tags jsonb,

  -- provenance for policies derived from another table's policy set
  -- (see metaschema_public.derives); both are set on derived policies,
  -- both NULL on hand-authored ones
  derived_from_table_id uuid,
  derived_from_policy_id uuid,

  category metaschema_public.object_category NOT NULL DEFAULT 'app',

  tags citext[] NOT NULL DEFAULT '{}',

  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),

  CONSTRAINT db_fkey FOREIGN KEY (database_id) REFERENCES metaschema_public.database (id) ON DELETE CASCADE,
  CONSTRAINT table_fkey FOREIGN KEY (table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
  CONSTRAINT derived_from_table_fkey FOREIGN KEY (derived_from_table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
  CONSTRAINT derived_from_policy_fkey FOREIGN KEY (derived_from_policy_id) REFERENCES metaschema_public.policy (id) ON DELETE CASCADE,

  CONSTRAINT derived_from_both_or_neither CHECK (
    (derived_from_table_id IS NULL) = (derived_from_policy_id IS NULL)
  ),

  CONSTRAINT policy_with_check_shape CHECK (
    with_check IS NULL OR (
      jsonb_typeof(with_check) = 'object'
      AND with_check ? '$type'
      AND jsonb_typeof(with_check->'$type') = 'string'
    )
  ),

  UNIQUE (table_id, name)
);

COMMENT ON COLUMN metaschema_public.policy.with_check IS
  'Optional WITH CHECK override node {"$type": "Authz...", "data": {...}}. Only valid for UPDATE policies; NULL inherits the USING expression.';


CREATE INDEX policy_database_id_idx ON metaschema_public.policy ( database_id );
CREATE INDEX policy_derived_from_table_id_idx ON metaschema_public.policy ( derived_from_table_id ) WHERE derived_from_table_id IS NOT NULL;
CREATE INDEX policy_derived_from_policy_id_idx ON metaschema_public.policy ( derived_from_policy_id ) WHERE derived_from_policy_id IS NOT NULL;

COMMIT;
