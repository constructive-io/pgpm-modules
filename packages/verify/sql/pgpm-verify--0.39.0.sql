\echo Use "CREATE EXTENSION pgpm-verify" to load this file. \quit
CREATE FUNCTION assert_relkind_label(
  _relkind "char"
) RETURNS text AS $EOFCODE$
    SELECT
        CASE _relkind
        WHEN 'r' THEN 'an ordinary table'
        WHEN 'p' THEN 'a partitioned table'
        WHEN 'v' THEN 'a view'
        WHEN 'm' THEN 'a materialized view'
        WHEN 'i' THEN 'an index'
        WHEN 'I' THEN 'a partitioned index'
        WHEN 'S' THEN 'a sequence'
        WHEN 'f' THEN 'a foreign table'
        WHEN 'c' THEN 'a composite type'
        WHEN 't' THEN 'a TOAST table'
        ELSE format('a relation of kind %L', _relkind)
        END;
$EOFCODE$ LANGUAGE sql IMMUTABLE;

CREATE FUNCTION assert_trigger_type_label(
  _tgtype int
) RETURNS text AS $EOFCODE$
DECLARE
    events text[] = ARRAY[]::text[];
BEGIN
    IF (_tgtype & 4) = 4 THEN
        events := array_append(events, 'INSERT');
    END IF;

    IF (_tgtype & 8) = 8 THEN
        events := array_append(events, 'DELETE');
    END IF;

    IF (_tgtype & 16) = 16 THEN
        events := array_append(events, 'UPDATE');
    END IF;

    IF (_tgtype & 32) = 32 THEN
        events := array_append(events, 'TRUNCATE');
    END IF;

    RETURN format('%s %s FOR EACH %s',
        CASE
        WHEN (_tgtype & 64) = 64 THEN 'INSTEAD OF'
        WHEN (_tgtype & 2) = 2 THEN 'BEFORE'
        ELSE 'AFTER'
        END,
        array_to_string(events, ' OR '),
        CASE WHEN (_tgtype & 1) = 1 THEN 'ROW' ELSE 'STATEMENT' END);
END;
$EOFCODE$ LANGUAGE plpgsql IMMUTABLE;

CREATE FUNCTION assert_policy_command_label(
  _polcmd "char"
) RETURNS text AS $EOFCODE$
    SELECT
        CASE _polcmd
        WHEN '*' THEN 'ALL'
        WHEN 'r' THEN 'SELECT'
        WHEN 'a' THEN 'INSERT'
        WHEN 'w' THEN 'UPDATE'
        WHEN 'd' THEN 'DELETE'
        ELSE format('command %L', _polcmd)
        END;
$EOFCODE$ LANGUAGE sql IMMUTABLE;

CREATE FUNCTION assert_function(
  _function regprocedure,
  _return_type regtype DEFAULT NULL,
  _returns_set boolean DEFAULT NULL,
  _security_definer boolean DEFAULT NULL,
  _volatility text DEFAULT NULL
) RETURNS boolean AS $EOFCODE$
DECLARE
    proc pg_catalog.pg_proc%ROWTYPE;
    found_volatility text;
BEGIN
    SELECT
        * INTO STRICT proc
    FROM
        pg_catalog.pg_proc
    WHERE
        oid = _function;

    IF _return_type IS NOT NULL AND proc.prorettype <> _return_type THEN
        RAISE EXCEPTION 'Function % must return %, found %', _function, _return_type, proc.prorettype::regtype
            USING HINT = 'The return type changed; callers and views built on it will break.';
    END IF;

    IF _returns_set IS NOT NULL AND proc.proretset <> _returns_set THEN
        RAISE EXCEPTION 'Function % must return %', _function,
            CASE WHEN _returns_set THEN 'a set' ELSE 'a single row' END;
    END IF;

    IF _security_definer IS NOT NULL AND proc.prosecdef <> _security_definer THEN
        RAISE EXCEPTION 'Function % must be SECURITY %', _function,
            CASE WHEN _security_definer THEN 'DEFINER' ELSE 'INVOKER' END
            USING HINT = 'An unintended SECURITY DEFINER runs as the owner and bypasses RLS.';
    END IF;

    IF _volatility IS NOT NULL THEN
        found_volatility := CASE proc.provolatile
        WHEN 'i' THEN 'IMMUTABLE'
        WHEN 's' THEN 'STABLE'
        ELSE 'VOLATILE'
        END;

        IF found_volatility <> upper(_volatility) THEN
            RAISE EXCEPTION 'Function % must be %, found %', _function, upper(_volatility), found_volatility;
        END IF;
    END IF;

    RETURN TRUE;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE;

CREATE FUNCTION assert_table(
  _table regclass,
  _partitioned boolean DEFAULT false,
  _is_partition boolean DEFAULT NULL
) RETURNS boolean AS $EOFCODE$
DECLARE
    rel pg_catalog.pg_class%ROWTYPE;
    -- plpgsql reads an IF condition up to the first THEN, so a CASE cannot be
    -- inlined there.
    wanted_kind "char" = CASE WHEN _partitioned THEN 'p' ELSE 'r' END;
BEGIN
    SELECT
        * INTO STRICT rel
    FROM
        pg_catalog.pg_class
    WHERE
        oid = _table;

    IF rel.relkind <> wanted_kind THEN
        RAISE EXCEPTION 'Relation % must be %, found %', _table,
            CASE WHEN _partitioned THEN 'a partitioned table' ELSE 'an ordinary table' END,
            assert_relkind_label (rel.relkind);
    END IF;

    IF _is_partition IS NOT NULL AND rel.relispartition <> _is_partition THEN
        RAISE EXCEPTION 'Table % must % a partition of another table', _table,
            CASE WHEN _is_partition THEN 'be' ELSE 'not be' END;
    END IF;

    RETURN TRUE;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE;

CREATE FUNCTION assert_view(
  _view regclass,
  _materialized boolean DEFAULT false,
  _security_invoker boolean DEFAULT NULL
) RETURNS boolean AS $EOFCODE$
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
$EOFCODE$ LANGUAGE plpgsql STABLE;

CREATE FUNCTION assert_view_rule(
  _view regclass,
  _rule name,
  _event text DEFAULT NULL
) RETURNS boolean AS $EOFCODE$
DECLARE
    found_event "char";
    wanted_event "char";
BEGIN
    SELECT
        ev_type INTO STRICT found_event
    FROM
        pg_catalog.pg_rewrite
    WHERE
        ev_class = _view
        AND rulename = _rule;

    IF _event IS NOT NULL THEN
        -- pg_rewrite.ev_type: 1 SELECT, 2 UPDATE, 3 INSERT, 4 DELETE.
        wanted_event := CASE lower(_event)
        WHEN 'select' THEN '1'
        WHEN 'update' THEN '2'
        WHEN 'insert' THEN '3'
        WHEN 'delete' THEN '4'
        END;

        IF wanted_event IS NULL THEN
            RAISE EXCEPTION 'Unsupported rule event --> %', _event;
        END IF;

        IF found_event <> wanted_event THEN
            RAISE EXCEPTION 'Rule % on % must fire on %', _rule, _view, upper(_event);
        END IF;
    END IF;

    RETURN TRUE;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE;

CREATE FUNCTION assert_index(
  _index regclass,
  _table regclass DEFAULT NULL,
  _unique boolean DEFAULT NULL
) RETURNS boolean AS $EOFCODE$
DECLARE
    ind pg_catalog.pg_index%ROWTYPE;
BEGIN
    SELECT
        * INTO STRICT ind
    FROM
        pg_catalog.pg_index
    WHERE
        indexrelid = _index;

    IF _table IS NOT NULL AND ind.indrelid <> _table THEN
        RAISE EXCEPTION 'Index % must index %, found %', _index, _table, ind.indrelid::regclass;
    END IF;

    IF _unique IS NOT NULL AND ind.indisunique <> _unique THEN
        RAISE EXCEPTION 'Index % must be %', _index,
            CASE WHEN _unique THEN 'UNIQUE' ELSE 'non-unique' END;
    END IF;

    IF NOT ind.indisvalid THEN
        RAISE EXCEPTION 'Index % must be valid', _index
            USING HINT = 'An invalid index is ignored by the planner and enforces nothing.';
    END IF;

    RETURN TRUE;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE;

CREATE FUNCTION assert_trigger(
  _table regclass,
  _trigger name,
  _function regproc DEFAULT NULL,
  _tgtype int DEFAULT NULL,
  _enabled boolean DEFAULT true
) RETURNS boolean AS $EOFCODE$
DECLARE
    trg pg_catalog.pg_trigger%ROWTYPE;
BEGIN
    SELECT
        * INTO STRICT trg
    FROM
        pg_catalog.pg_trigger
    WHERE
        tgrelid = _table
        AND tgname = _trigger;

    IF _function IS NOT NULL AND trg.tgfoid <> _function THEN
        RAISE EXCEPTION 'Trigger % on % must call %, found %', _trigger, _table, _function, trg.tgfoid::regproc;
    END IF;

    IF _tgtype IS NOT NULL AND trg.tgtype <> _tgtype THEN
        RAISE EXCEPTION 'Trigger % on % must be %, found %', _trigger, _table,
            assert_trigger_type_label (_tgtype), assert_trigger_type_label (trg.tgtype);
    END IF;

    IF _enabled IS NOT NULL AND (trg.tgenabled <> 'D') <> _enabled THEN
        RAISE EXCEPTION 'Trigger % on % must be %', _trigger, _table,
            CASE WHEN _enabled THEN 'enabled' ELSE 'disabled' END
            USING HINT = 'ALTER TABLE ... DISABLE TRIGGER leaves the catalog row in place.';
    END IF;

    RETURN TRUE;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE;

CREATE FUNCTION assert_policy(
  _table regclass,
  _policy name,
  _command text DEFAULT NULL,
  _permissive boolean DEFAULT NULL,
  _has_qual boolean DEFAULT NULL,
  _has_with_check boolean DEFAULT NULL
) RETURNS boolean AS $EOFCODE$
DECLARE
    pol pg_catalog.pg_policy%ROWTYPE;
    wanted_cmd "char";
BEGIN
    SELECT
        * INTO STRICT pol
    FROM
        pg_catalog.pg_policy
    WHERE
        polrelid = _table
        AND polname = _policy;

    IF _command IS NOT NULL THEN
        -- pg_policy.polcmd: '*' ALL, 'r' SELECT, 'a' INSERT, 'w' UPDATE, 'd' DELETE.
        wanted_cmd := CASE lower(_command)
        WHEN 'all' THEN '*'
        WHEN 'select' THEN 'r'
        WHEN 'insert' THEN 'a'
        WHEN 'update' THEN 'w'
        WHEN 'delete' THEN 'd'
        END;

        IF wanted_cmd IS NULL THEN
            RAISE EXCEPTION 'Unsupported policy command --> %', _command;
        END IF;

        IF pol.polcmd <> wanted_cmd THEN
            RAISE EXCEPTION 'Policy % on % must apply to %, found %', _policy, _table,
                upper(_command), assert_policy_command_label (pol.polcmd);
        END IF;
    END IF;

    IF _permissive IS NOT NULL AND pol.polpermissive <> _permissive THEN
        RAISE EXCEPTION 'Policy % on % must be %', _policy, _table,
            CASE WHEN _permissive THEN 'PERMISSIVE' ELSE 'RESTRICTIVE' END
            USING HINT = 'A restrictive policy turned permissive widens access instead of narrowing it.';
    END IF;

    IF _has_qual IS NOT NULL AND (pol.polqual IS NOT NULL) <> _has_qual THEN
        RAISE EXCEPTION 'Policy % on % must % a USING clause', _policy, _table,
            CASE WHEN _has_qual THEN 'carry' ELSE 'not carry' END;
    END IF;

    IF _has_with_check IS NOT NULL AND (pol.polwithcheck IS NOT NULL) <> _has_with_check THEN
        RAISE EXCEPTION 'Policy % on % must % a WITH CHECK clause', _policy, _table,
            CASE WHEN _has_with_check THEN 'carry' ELSE 'not carry' END;
    END IF;

    RETURN TRUE;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE;

CREATE FUNCTION assert_schema(
  _schema regnamespace
) RETURNS boolean AS $EOFCODE$
BEGIN
    PERFORM
        1
    FROM
        pg_catalog.pg_namespace
    WHERE
        oid = _schema;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Nonexistent schema --> %', _schema;
    END IF;

    RETURN TRUE;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE;

CREATE FUNCTION assert_table_grant(
  _relation regclass,
  _role name,
  _privilege text,
  _columns text[] DEFAULT NULL,
  _granted boolean DEFAULT true
) RETURNS boolean AS $EOFCODE$
DECLARE
    col text;
    offending text[] = ARRAY[]::text[];
    held boolean;
BEGIN
    IF _columns IS NULL OR cardinality(_columns) = 0 THEN
        held = pg_catalog.has_table_privilege(_role, _relation, _privilege);

        IF held <> _granted THEN
            RAISE EXCEPTION 'Role % must % % on %', _role,
                CASE WHEN _granted THEN 'hold' ELSE 'not hold' END,
                _privilege, _relation;
        END IF;

        RETURN TRUE;
    END IF;

    FOREACH col IN ARRAY _columns LOOP
        IF pg_catalog.has_column_privilege(_role, _relation, col, _privilege) <> _granted THEN
            offending = offending || col;
        END IF;
    END LOOP;

    IF cardinality(offending) > 0 THEN
        RAISE EXCEPTION 'Role % must % % on %.(%)', _role,
            CASE WHEN _granted THEN 'hold' ELSE 'not hold' END,
            _privilege, _relation, array_to_string(offending, ', ');
    END IF;

    RETURN TRUE;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE;

CREATE FUNCTION assert_table_security(
  _table regclass,
  _enabled boolean DEFAULT true,
  _forced boolean DEFAULT NULL
) RETURNS boolean AS $EOFCODE$
DECLARE
    rel pg_catalog.pg_class%ROWTYPE;
BEGIN
    SELECT
        * INTO STRICT rel
    FROM
        pg_catalog.pg_class
    WHERE
        oid = _table;

    IF rel.relrowsecurity <> _enabled THEN
        RAISE EXCEPTION 'Row level security on % must be %', _table,
            CASE WHEN _enabled THEN 'enabled' ELSE 'disabled' END;
    END IF;

    IF _forced IS NOT NULL AND rel.relforcerowsecurity <> _forced THEN
        RAISE EXCEPTION 'Row level security on % must be % for the owner', _table,
            CASE WHEN _forced THEN 'forced' ELSE 'not forced' END;
    END IF;

    RETURN TRUE;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE;

CREATE FUNCTION assert_function_grant(
  _function regprocedure,
  _role name,
  _privilege text DEFAULT 'EXECUTE',
  _granted boolean DEFAULT true
) RETURNS boolean AS $EOFCODE$
BEGIN
    IF pg_catalog.has_function_privilege(_role, _function, _privilege) <> _granted THEN
        RAISE EXCEPTION 'Role % must % % on %', _role,
            CASE WHEN _granted THEN 'hold' ELSE 'not hold' END,
            _privilege, _function;
    END IF;

    RETURN TRUE;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE;

CREATE FUNCTION assert_type(
  _type regtype,
  _kind "char" DEFAULT NULL
) RETURNS boolean AS $EOFCODE$
DECLARE
    typ pg_catalog.pg_type%ROWTYPE;
BEGIN
    SELECT
        * INTO STRICT typ
    FROM
        pg_catalog.pg_type
    WHERE
        oid = _type;

    IF typ.typtype = 'd' THEN
        RAISE EXCEPTION '% is a domain', _type
            USING HINT = 'Use assert_domain for a domain.';
    END IF;

    IF _kind IS NOT NULL AND typ.typtype <> _kind THEN
        RAISE EXCEPTION 'Type % must be typtype %, found %', _type, _kind, typ.typtype;
    END IF;

    RETURN TRUE;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE;

CREATE FUNCTION assert_domain(
  _domain regtype,
  _base regtype DEFAULT NULL,
  _not_null boolean DEFAULT NULL,
  _constraints int DEFAULT NULL
) RETURNS boolean AS $EOFCODE$
DECLARE
    typ pg_catalog.pg_type%ROWTYPE;
    found_constraints int;
BEGIN
    SELECT
        * INTO STRICT typ
    FROM
        pg_catalog.pg_type
    WHERE
        oid = _domain;

    IF typ.typtype <> 'd' THEN
        RAISE EXCEPTION '% must be a domain', _domain;
    END IF;

    IF _base IS NOT NULL AND typ.typbasetype <> _base THEN
        RAISE EXCEPTION 'Domain % must be built on %, found %', _domain, _base,
            typ.typbasetype::regtype;
    END IF;

    IF _not_null IS NOT NULL AND typ.typnotnull <> _not_null THEN
        RAISE EXCEPTION 'Domain % must be %', _domain,
            CASE WHEN _not_null THEN 'NOT NULL' ELSE 'nullable' END;
    END IF;

    IF _constraints IS NOT NULL THEN
        SELECT
            count(*) INTO found_constraints
        FROM
            pg_catalog.pg_constraint
        WHERE
            contypid = _domain;

        IF found_constraints <> _constraints THEN
            RAISE EXCEPTION 'Domain % must carry % constraint(s), found %', _domain,
                _constraints, found_constraints;
        END IF;
    END IF;

    RETURN TRUE;
END;
$EOFCODE$ LANGUAGE plpgsql STABLE;