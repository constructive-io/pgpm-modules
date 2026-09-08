-- Deploy schemas/metaschema_public/tables/database/table to pg

-- requires: schemas/metaschema_public/schema

BEGIN;

CREATE TABLE metaschema_public.database (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  owner_id uuid,
  schema_hash text,
  
  name text,
  label text,
  
  hash uuid,

  -- Singleton flag marking the platform (constructive) database itself.
  -- Write-once: first row to set it wins; immutable once true.
  platform boolean NOT NULL DEFAULT false,

  -- Operational access standing. NULL = in good standing; set = every serving
  -- lane (pg-wire proxy, gateways, GraphQL, workers) refuses work for this
  -- database. System-controlled: tenants read it, only the system role or a
  -- platform admin writes it (guard trigger in the metaschema module). The
  -- reason names who set it — 'billing' clears automatically when allowance
  -- returns, 'admin' only when an admin lifts it. Not an audit log: billing
  -- state is the record of WHY; this is only the current on/off derived from it.
  suspended_at timestamptz,
  suspended_reason text,

  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),

  unique(schema_hash)
);

ALTER TABLE metaschema_public.database
  ADD CONSTRAINT db_namechk CHECK (char_length(name) > 2);

ALTER TABLE metaschema_public.database
  ADD CONSTRAINT database_suspension_chk CHECK (
    (suspended_at IS NULL) = (suspended_reason IS NULL)
    AND (suspended_reason IS NULL OR suspended_reason IN ('billing', 'admin'))
  );

CREATE UNIQUE INDEX databases_database_platform_singleton_idx
  ON metaschema_public.database (platform)
  WHERE platform;
CREATE INDEX database_owner_id_idx ON metaschema_public.database ( owner_id );
CREATE INDEX database_suspended_at_idx ON metaschema_public.database ( suspended_at );

COMMENT ON COLUMN metaschema_public.database.schema_hash IS '@behavior -*';
COMMENT ON COLUMN metaschema_public.database.suspended_at IS '@behavior -insert -update';
COMMENT ON COLUMN metaschema_public.database.suspended_reason IS '@behavior -insert -update';

COMMIT;
