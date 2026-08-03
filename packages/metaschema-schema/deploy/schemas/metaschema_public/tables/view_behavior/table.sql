-- Deploy schemas/metaschema_public/tables/view_behavior/table to pg

-- requires: schemas/metaschema_public/schema
-- requires: schemas/metaschema_public/tables/database/table
-- requires: schemas/metaschema_public/tables/view/table

BEGIN;

-- One row per PostGraphile v5 behavior fragment attached to a view. An
-- entity's fragments are emitted, ordered by sort_order, as a single
-- '@behavior <fragments>' smart tag on the corresponding database object:
--
--   ('-', 'insert') + ('-', 'update')  ->  @behavior -insert -update
--
-- `scope` is the fragment's natural key, so an entity carries at most one
-- fragment per scope: writers upsert on (view_id, scope) rather than appending a
-- second fragment that would silently shadow the first.
CREATE TABLE metaschema_public.view_behavior (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  database_id uuid NOT NULL DEFAULT uuid_nil(),

  view_id uuid NOT NULL REFERENCES metaschema_public.view (id) ON DELETE CASCADE,

  -- '+' (grant) or '-' (revoke). PostGraphile infers '+' when the modifier is
  -- omitted; we always store it explicitly so fragments round-trip.
  modifier char(1) NOT NULL DEFAULT '+',

  -- One or more camelCase words (or '*') joined by ':', e.g. 'insert',
  -- 'resource:connection:filter', 'query:*:filter'.
  scope text NOT NULL,

  -- Emission order within the entity. Later fragments win in PostGraphile, so
  -- sort_order is meaningful when scopes overlap (e.g. '*' before 'insert').
  sort_order int NOT NULL DEFAULT 0,

  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),

  CONSTRAINT db_fkey FOREIGN KEY (database_id) REFERENCES metaschema_public.database (id) ON DELETE CASCADE,

  CONSTRAINT view_behavior_modifier_check CHECK (modifier IN ('+', '-')),

  CONSTRAINT view_behavior_scope_check CHECK (
    scope ~ '^([a-zA-Z][a-zA-Z0-9]*|\*)(:([a-zA-Z][a-zA-Z0-9]*|\*))*$'
  ),

  CONSTRAINT view_behavior_scope_key UNIQUE (view_id, scope)
);

CREATE INDEX view_behavior_database_id_idx ON metaschema_public.view_behavior ( database_id );

COMMIT;
