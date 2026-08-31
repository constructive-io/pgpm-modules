-- Deploy schemas/metaschema_public/tables/function/table to pg

-- requires: schemas/metaschema_public/schema
-- requires: schemas/metaschema_public/tables/database/table
-- requires: schemas/metaschema_public/tables/schema/table
-- requires: schemas/metaschema_public/types/object_category

BEGIN;

CREATE TABLE metaschema_public.function (
    id uuid PRIMARY KEY DEFAULT uuidv7(),
    database_id uuid NOT NULL,
    schema_id uuid NOT NULL,

    name text NOT NULL,

    -- What this row is:
    --   'reservation' — name-only. The function is emitted by a generator and
    --                   this row exists to hand out a stable, FK-able id and to
    --                   reserve (schema_id, name) against a customer-defined
    --                   function taking the same name.
    --   'sql'         — this row owns the definition of a pure SQL function.
    --   'plpgsql'     — this row owns the definition of a PL/pgSQL function.
    --   'trigger'     — this row owns the definition of a PL/pgSQL trigger
    --                   function: no arguments, RETURNS trigger, never callable
    --                   through the API. It fires inside whatever transaction
    --                   writes the table it is attached to, so it is gated,
    --                   validated and emitted separately from a plain function.
    -- For a definition row the kind is also the function's LANGUAGE ('trigger'
    -- being PL/pgSQL), so the two can never disagree.
    kind text NOT NULL DEFAULT 'reservation',

    -- Signature (definition rows only).
    -- arguments: [{ "name": "user_id", "type": { "name": "uuid" }, "mode": "in", "default": ... }, …]
    -- returns:   { "type": { "name": "boolean" } } | { "setof": true, "type": … } | { "table": [ … ] }
    arguments jsonb NOT NULL DEFAULT '[]',
    returns jsonb,

    volatility text,
    is_strict boolean NOT NULL DEFAULT false,

    -- SECURITY DEFINER is deliberately not expressible: a customer-owned
    -- function runs as its invoker and stays subject to RLS.
    security_invoker boolean NOT NULL DEFAULT true,

    -- Tier A authoring: a typed Function* node type plus its parameters, the
    -- same shape metaschema_public.view uses for View* types. The body AST is
    -- derived from these at generation time.
    function_type text,
    data jsonb DEFAULT '{}',

    -- Tier B authoring: the validated native AST. For 'sql' a statement AST,
    -- for 'plpgsql' the complete PLpgSQL_function AST including its top-level
    -- `datums` array — never a body fragment, because NEW/OLD field references
    -- resolve by datum index.
    body_ast jsonb,

    smart_tags jsonb,

    -- Whether this function is published to the generated API.
    --
    -- PostGraphile exposes every function it finds in a published schema, so a
    -- customer function landing in app_public would become a query or mutation
    -- field by existing. Publishing executable code is a separate decision from
    -- authoring it, and the safe answer when nobody made that decision is no:
    -- the default is false, and provisioning both denies every API behavior on
    -- the emitted function and withholds EXECUTE until this is turned on.
    api_exposed boolean NOT NULL DEFAULT false,

    category metaschema_public.object_category NOT NULL DEFAULT 'app',

    tags citext[] NOT NULL DEFAULT '{}',

    --
    CONSTRAINT function_kind_valid CHECK (kind IN ('reservation', 'sql', 'plpgsql', 'trigger')),

    CONSTRAINT function_volatility_valid CHECK (
        volatility IS NULL OR volatility IN ('IMMUTABLE', 'STABLE', 'VOLATILE')
    ),

    CONSTRAINT function_security_invoker_only CHECK (security_invoker),

    -- A reservation is a name held for a generated function, whose own
    -- generator decides its API surface; the flag would describe nothing.
    CONSTRAINT function_reservation_not_api_exposed CHECK (
        kind <> 'reservation' OR NOT api_exposed
    ),

    -- A reservation row carries no executable definition.
    CONSTRAINT function_reservation_has_no_definition CHECK (
        kind <> 'reservation'
        OR (
            arguments = '[]'::jsonb
            AND returns IS NULL
            AND volatility IS NULL
            AND function_type IS NULL
            AND body_ast IS NULL
        )
    ),

    -- A trigger function takes no arguments and returns the trigger
    -- pseudo-type: PostgreSQL calls it with the row in NEW/OLD rather than
    -- through a signature, and any other shape cannot be attached at all.
    CONSTRAINT function_trigger_signature CHECK (
        kind <> 'trigger'
        OR (
            arguments = '[]'::jsonb
            AND returns = '{"type": {"name": "trigger"}}'::jsonb
            AND volatility = 'VOLATILE'
            AND function_type IS NULL
            AND body_ast IS NOT NULL
        )
    ),

    -- A trigger function is reached by firing, not by calling: it needs no
    -- EXECUTE grant, and exposing it would publish a function whose only
    -- argument type cannot be spelled in a GraphQL field.
    CONSTRAINT function_trigger_not_api_exposed CHECK (
        kind <> 'trigger' OR NOT api_exposed
    ),

    -- A definition row carries a complete signature and at least one authoring
    -- tier to generate the body from.
    CONSTRAINT function_definition_complete CHECK (
        kind = 'reservation'
        OR (
            returns IS NOT NULL
            AND volatility IS NOT NULL
            AND (function_type IS NOT NULL OR body_ast IS NOT NULL)
        )
    ),

    CONSTRAINT db_fkey FOREIGN KEY (database_id) REFERENCES metaschema_public.database (id) ON DELETE CASCADE,
    CONSTRAINT schema_fkey FOREIGN KEY (schema_id) REFERENCES metaschema_public.schema (id) ON DELETE CASCADE,

    UNIQUE (schema_id, name)
);

CREATE INDEX function_database_id_idx ON metaschema_public.function ( database_id );
CREATE INDEX function_kind_idx ON metaschema_public.function ( kind );

COMMIT;
