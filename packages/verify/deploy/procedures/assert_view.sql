-- Deploy procedures/assert_view to pg

-- requires: procedures/assert_relkind_label

BEGIN;

-- Asserts a view exists under exactly this name, is the kind of view it is
-- supposed to be, and still reads with the security context it was created
-- with.
--
--   SELECT assert_view('my_schema.my_view'::regclass);
--   SELECT assert_view('my_schema.my_matview'::regclass, _materialized => true);
--
-- security_invoker is the security-relevant half: a view that silently loses it
-- reads its underlying tables with the definer's RLS.

CREATE FUNCTION assert_view (
    _view regclass,
    _materialized boolean DEFAULT false,
    _security_invoker boolean DEFAULT NULL
)
    RETURNS boolean
    AS $$
DECLARE
    rel pg_catalog.pg_class%ROWTYPE;
    invoker boolean;
    -- plpgsql reads an IF condition up to the first THEN, so a CASE cannot be
    -- inlined there.
    wanted_kind "char" = CASE WHEN _materialized THEN 'm' ELSE 'v' END;
BEGIN
    SELECT
        * INTO STRICT rel
    FROM
        pg_catalog.pg_class
    WHERE
        oid = _view;

    IF rel.relkind <> wanted_kind THEN
        RAISE EXCEPTION 'Relation % must be %, found %', _view,
            CASE WHEN _materialized THEN 'a materialized view' ELSE 'a view' END,
            assert_relkind_label (rel.relkind);
    END IF;

    IF _security_invoker IS NOT NULL THEN
        IF _materialized THEN
            RAISE EXCEPTION 'Materialized view % cannot carry security_invoker', _view
                USING HINT = 'security_invoker is an ordinary-view reloption.';
        END IF;

        -- reloptions is NULL for a view carrying no options at all, and
        -- `= ANY (NULL)` is NULL rather than false.
        invoker := coalesce('security_invoker=true' = ANY (rel.reloptions), false);

        IF invoker <> _security_invoker THEN
            RAISE EXCEPTION 'View % must be a % view', _view,
                CASE WHEN _security_invoker THEN 'security_invoker' ELSE 'security definer' END
                USING HINT = 'A view that loses security_invoker reads its tables with the owner''s RLS.';
        END IF;
    END IF;

    RETURN TRUE;
END;
$$
LANGUAGE 'plpgsql'
STABLE;

COMMIT;
