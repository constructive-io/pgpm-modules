-- Deploy schemas/metaschema_public/tables/trigger/table to pg

-- requires: schemas/metaschema_public/schema
-- requires: schemas/metaschema_public/tables/table/table
-- requires: schemas/metaschema_public/tables/function/table
-- requires: schemas/metaschema_public/types/object_category

BEGIN;

-- https://www.postgresql.org/docs/12/sql-createtrigger.html

CREATE TABLE metaschema_public.trigger (
  id uuid PRIMARY KEY DEFAULT uuidv7(),
  database_id uuid NOT NULL DEFAULT uuid_nil(),
  
  table_id uuid NOT NULL,
  name text NOT NULL,
  event text, -- INSERT, UPDATE, DELETE, or TRUNCATE
  function_name text,

  -- What this row is, mirroring metaschema_public.function.kind:
  --   'reservation' — name-only. The trigger itself is emitted by a generator,
  --                   or captured from the catalog by introspection, and this
  --                   row exists to hand out a stable, FK-able id and to
  --                   reserve (table_id, name) against a customer attachment
  --                   taking the same name.
  --   'attachment'  — this row owns the definition of a customer trigger: which
  --                   customer function fires, on which events, under which
  --                   condition. The physical trigger is re-derived from the row.
  kind text NOT NULL DEFAULT 'reservation',

  -- Customer trigger attachment. A row with function_id set attaches a
  -- customer-defined trigger function (metaschema_public.function,
  -- kind='trigger') to the target table. Generated/reservation rows leave all
  -- of these NULL and keep their current lifecycle.
  function_id uuid,

  -- Stored as readable enums, translated to the trigger type bitmask at
  -- emission time.
  timing text,
  events text[],
  for_each_row boolean,

  -- Optional WHEN condition. A condition is an AST, never a string or DSL;
  -- it is validated and deparsed at emission time.
  when_ast jsonb,

  smart_tags jsonb,

  category metaschema_public.object_category NOT NULL DEFAULT 'app',

  tags citext[] NOT NULL DEFAULT '{}',

  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),

  CONSTRAINT db_fkey FOREIGN KEY (database_id) REFERENCES metaschema_public.database (id) ON DELETE CASCADE,
  CONSTRAINT table_fkey FOREIGN KEY (table_id) REFERENCES metaschema_public.table (id) ON DELETE CASCADE,
  -- RESTRICT rather than CASCADE: dropping a trigger function that is still
  -- attached is a mistake to report, not an attachment to delete silently. An
  -- attachment is removed by deleting the trigger row, which is the only path
  -- that also drops the physical trigger.
  CONSTRAINT function_fkey FOREIGN KEY (function_id) REFERENCES metaschema_public.function (id) ON DELETE RESTRICT,

  CONSTRAINT trigger_kind_valid CHECK (kind IN ('reservation', 'attachment')),

  -- The kind and the relation are two spellings of the same fact, so neither
  -- can be set without the other: a reservation never names a function, and an
  -- attachment is nothing without one.
  CONSTRAINT trigger_kind_matches_attachment CHECK (
    (kind = 'attachment') = (function_id IS NOT NULL)
  ),

  -- A reservation carries no attachment definition. An empty events array is
  -- accepted alongside NULL because that is how the seed exporter round-trips a
  -- null array, and both say the same thing: no events.
  CONSTRAINT trigger_reservation_has_no_definition CHECK (
    kind <> 'reservation'
    OR (
      timing IS NULL
      AND coalesce(cardinality(events), 0) = 0
      AND for_each_row IS NULL
      AND when_ast IS NULL
    )
  ),

  -- event and function_name are the generated-trigger spelling: a single event
  -- and a physical function name, filled in by whichever generator emitted the
  -- trigger. An attachment says the same things in function_id and events, and
  -- resolves the physical name from the function row, so carrying both would be
  -- two answers to one question.
  CONSTRAINT trigger_attachment_has_no_legacy_definition CHECK (
    kind <> 'attachment'
    OR (event IS NULL AND function_name IS NULL)
  ),

  -- The customer attachment posture: AFTER, FOR EACH ROW, on a non-empty
  -- subset of {INSERT, UPDATE, DELETE}. BEFORE (a body could rewrite NEW
  -- before RLS/checks see it), TRUNCATE, statement-level, constraint/
  -- deferrable triggers and transition relations are not representable.
  CONSTRAINT trigger_customer_attachment_shape CHECK (
    function_id IS NULL
    OR (
      timing = 'AFTER'
      AND for_each_row
      AND events IS NOT NULL
      AND cardinality(events) > 0
      AND events <@ ARRAY['INSERT', 'UPDATE', 'DELETE']
    )
  ),

  UNIQUE(table_id, name)
);


CREATE INDEX trigger_database_id_idx ON metaschema_public.trigger ( database_id );
CREATE INDEX trigger_function_id_idx ON metaschema_public.trigger ( function_id );

COMMIT;
