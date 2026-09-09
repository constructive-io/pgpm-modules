-- Deploy schemas/metaschema_private/procedures/is_valid_step_up to pg
-- requires: schemas/metaschema_private/schema

BEGIN;

-- Validates the declarative step_up field on metaschema_public.table.
-- Expected shape: a non-empty jsonb object mapping DML verbs to a step-up spec:
--   { "DELETE": "mfa", "UPDATE": true }
--   { "DELETE": { "type": "mfa", "min_age": "24 hours" } }
-- Keys must be INSERT, UPDATE, or DELETE.
-- Values must be one of:
--   - true (default step-up type)
--   - a type string: 'password', 'mfa', 'fresh_auth'
--     ('password_or_mfa' is the legacy spelling of 'fresh_auth')
--   - an object with keys from {type, min_age, min_age_lookup, conditions}:
--       type    (optional): 'password', 'mfa', 'fresh_auth'
--       min_age (optional): a positive interval string (e.g. '6 hours');
--                           the guard only fires for rows older than this.
--                           Not allowed for INSERT (new rows have no age).
--       min_age_lookup (optional): per-row min_age resolution from a lookup
--                           table. Object with exactly {table_id (uuid),
--                           fk_field (text), min_age_field (text)}. Requires
--                           min_age as the fallback default. UPDATE/DELETE only.
--       min_age_anchor (optional): measure min_age from a related row's
--                           timestamp instead of the guarded row's created_at,
--                           for a configuration row that is replaced rather
--                           than edited. Object with exactly {table_id (uuid),
--                           fk_field (text), timestamp_field (text)}. Requires
--                           min_age, excludes min_age_lookup. UPDATE/DELETE only.
--       min_age_unless (optional): conditions tree (same grammar as
--                           conditions) that forfeits the min_age grace: a row
--                           younger than min_age is still guarded when it
--                           matches. Requires min_age; excludes min_age_lookup
--                           and min_age_anchor. UPDATE/DELETE only.
--       allow_system (optional): boolean; when true the system role
--                           (jwt.claims.role_type = 'system') skips the guard so
--                           provisioning paths without a session can write.
--       conditions (optional): declarative WHEN-clause tree gating the guard
--                           (compiled by metaschema_generators.build_condition_expr
--                           and validated through the ast_validate framework at
--                           apply time). Shape-validated here via
--                           is_valid_step_up_conditions.
--       related_conditions (optional): the guard arms on the row the written
--                           row points at rather than on the written row.
--                           Object with exactly {table_id (uuid), fk_field
--                           (text), conditions (tree over the related table)}.
--                           Tested in the trigger body, since a WHEN clause
--                           may not hold a subquery. Excludes min_age_lookup
--                           and min_age_anchor.
--       name (optional):    identifies one of several guards on a verb.
--   - a non-empty array of such objects when one verb needs guards of
--     differing posture. Names are unique lowercase snake_case; at most one
--     element is unnamed (the verb's default guard, keeping its historical
--     trigger name).

-- Shape validator for the conditions tree accepted by the declarative
-- step_up field. Mirrors the grammar of
-- metaschema_generators.build_condition_expr:
--   - array: implicit AND of nodes (must be non-empty)
--   - combinator object: exactly one of {"AND": [...]}, {"OR": [...]},
--     {"NOT": {...}}
--   - leaf object: {field, op, value?, row?, ref?} where op is one of
--     =, !=, >, <, >=, <=, LIKE, NOT LIKE, IS NULL, IS NOT NULL,
--     IS DISTINCT FROM; row is NEW or OLD; comparison ops require exactly
--     one of value (scalar) or ref ({field, row?}).
--   - predicate call leaf: {schema, function, args?} — schema and function name
--     are separate keys, as in the FieldGeneration DSL, and each arg is a column
--     reference ({field, row?}).
-- Field existence and AST safety are enforced at apply time by
-- build_condition_expr + ast_validate.validate_column_expression_ast, and so
-- is *which* predicate a call may name: the allow-list lives in
-- metaschema_generators.allowed_condition_calls(), which this immutable
-- shape check cannot reach across modules. A well-shaped call to an
-- unlisted predicate is therefore stored and rejected when the guard is
-- built, the same way a well-shaped reference to a missing column is.
CREATE FUNCTION metaschema_private.is_valid_step_up_conditions(cond jsonb)
RETURNS boolean AS $$
DECLARE
    -- node iteration
    v_i int;

    -- leaf validation
    v_key text;
    v_op text;

    -- ref validation (column-to-column comparison)
    v_ref jsonb;
    v_ref_key text;

    -- predicate call leaf argument validation
    v_arg jsonb;
BEGIN
    IF cond IS NULL THEN
        RETURN false;
    END IF;

    -- Array: implicit AND of all elements
    IF jsonb_typeof(cond) = 'array' THEN
        IF jsonb_array_length(cond) = 0 THEN
            RETURN false;
        END IF;
        FOR v_i IN 0..jsonb_array_length(cond) - 1 LOOP
            IF NOT metaschema_private.is_valid_step_up_conditions(cond -> v_i) THEN
                RETURN false;
            END IF;
        END LOOP;
        RETURN true;
    END IF;

    IF jsonb_typeof(cond) != 'object' OR cond = '{}'::jsonb THEN
        RETURN false;
    END IF;

    -- Combinator object: exactly one of AND / OR / NOT
    IF cond ? 'AND' OR cond ? 'OR' OR cond ? 'NOT' THEN
        IF (SELECT count(*) FROM jsonb_object_keys(cond)) != 1 THEN
            RETURN false;
        END IF;
        IF cond ? 'NOT' THEN
            RETURN metaschema_private.is_valid_step_up_conditions(cond -> 'NOT');
        END IF;
        IF jsonb_typeof(COALESCE(cond -> 'AND', cond -> 'OR')) != 'array' THEN
            RETURN false;
        END IF;
        RETURN metaschema_private.is_valid_step_up_conditions(COALESCE(cond -> 'AND', cond -> 'OR'));
    END IF;

    -- Predicate call leaf: {schema, function, args?}
    IF cond ? 'function' THEN
        FOR v_key IN SELECT key FROM jsonb_each(cond) LOOP
            IF v_key NOT IN ('schema', 'function', 'args') THEN
                RETURN false;
            END IF;
        END LOOP;

        -- A predicate is always schema-qualified: it is platform SQL named by
        -- the allow-list, never something resolved out of the search_path.
        IF jsonb_typeof(cond -> 'schema') IS DISTINCT FROM 'string'
           OR jsonb_typeof(cond -> 'function') IS DISTINCT FROM 'string' THEN
            RETURN false;
        END IF;

        IF cond ? 'args' THEN
            IF jsonb_typeof(cond -> 'args') != 'array' THEN
                RETURN false;
            END IF;

            FOR v_i IN 0..jsonb_array_length(cond -> 'args') - 1 LOOP
                v_arg := (cond -> 'args') -> v_i;
                IF jsonb_typeof(v_arg) != 'object' THEN
                    RETURN false;
                END IF;
                FOR v_key IN SELECT key FROM jsonb_each(v_arg) LOOP
                    IF v_key NOT IN ('field', 'row') THEN
                        RETURN false;
                    END IF;
                END LOOP;
                IF jsonb_typeof(v_arg -> 'field') IS DISTINCT FROM 'string' THEN
                    RETURN false;
                END IF;
                IF v_arg ? 'row' THEN
                    IF jsonb_typeof(v_arg -> 'row') != 'string'
                       OR upper(v_arg ->> 'row') NOT IN ('NEW', 'OLD') THEN
                        RETURN false;
                    END IF;
                END IF;
            END LOOP;
        END IF;

        RETURN true;
    END IF;

    -- Leaf condition: {field, op, value?, row?, ref?}
    FOR v_key IN SELECT key FROM jsonb_each(cond) LOOP
        IF v_key NOT IN ('field', 'op', 'value', 'row', 'ref') THEN
            RETURN false;
        END IF;
    END LOOP;

    IF jsonb_typeof(cond -> 'field') IS DISTINCT FROM 'string'
       OR jsonb_typeof(cond -> 'op') IS DISTINCT FROM 'string' THEN
        RETURN false;
    END IF;

    v_op := upper(cond ->> 'op');
    IF v_op NOT IN ('=', '!=', '>', '<', '>=', '<=', 'LIKE', 'NOT LIKE',
                    'IS NULL', 'IS NOT NULL', 'IS DISTINCT FROM') THEN
        RETURN false;
    END IF;

    IF cond ? 'row' THEN
        IF jsonb_typeof(cond -> 'row') != 'string'
           OR upper(cond ->> 'row') NOT IN ('NEW', 'OLD') THEN
            RETURN false;
        END IF;
    END IF;

    -- Operators without a right-hand side
    IF v_op IN ('IS NULL', 'IS NOT NULL', 'IS DISTINCT FROM') THEN
        IF cond ? 'value' OR cond ? 'ref' THEN
            RETURN false;
        END IF;
        RETURN true;
    END IF;

    -- Comparison operators require exactly one of value / ref
    IF (cond ? 'value') = (cond ? 'ref') THEN
        RETURN false;
    END IF;

    IF cond ? 'value' THEN
        IF jsonb_typeof(cond -> 'value') NOT IN ('string', 'number', 'boolean') THEN
            RETURN false;
        END IF;
        RETURN true;
    END IF;

    v_ref := cond -> 'ref';
    IF jsonb_typeof(v_ref) != 'object' THEN
        RETURN false;
    END IF;
    FOR v_ref_key IN SELECT key FROM jsonb_each(v_ref) LOOP
        IF v_ref_key NOT IN ('field', 'row') THEN
            RETURN false;
        END IF;
    END LOOP;
    IF jsonb_typeof(v_ref -> 'field') IS DISTINCT FROM 'string' THEN
        RETURN false;
    END IF;
    IF v_ref ? 'row' THEN
        IF jsonb_typeof(v_ref -> 'row') != 'string'
           OR upper(v_ref ->> 'row') NOT IN ('NEW', 'OLD') THEN
            RETURN false;
        END IF;
    END IF;

    RETURN true;
END;
$$
LANGUAGE 'plpgsql' IMMUTABLE;

CREATE FUNCTION metaschema_private.is_valid_step_up(step_up jsonb)
RETURNS boolean AS $$
DECLARE
    -- entry iteration
    v_key text;
    v_value jsonb;

    -- object value validation
    v_obj_key text;
    v_type jsonb;
    v_min_age jsonb;
    v_min_age_interval interval;

    -- min_age_lookup validation (per-row lookup windows)
    v_min_age_lookup jsonb;
    v_lookup_key text;
    v_lookup_table_id uuid;

    -- min_age_anchor validation (window measured from a related row)
    v_min_age_anchor jsonb;
    v_anchor_key text;
    v_anchor_table_id uuid;

    -- min_age_unless validation (grace forfeited when the tree matches)
    v_min_age_unless jsonb;

    -- allow_system validation (system-role exemption)
    v_allow_system jsonb;

    -- conditions validation (declarative WHEN-clause tree)
    v_conditions jsonb;

    -- related_conditions validation (guard arms on a related row)
    v_related_conditions jsonb;
    v_related_key text;
    v_related_table_id uuid;

    -- named-guard array validation
    v_guard jsonb;
    v_guard_names text[];
BEGIN
    IF step_up IS NULL THEN
        RETURN false;
    END IF;

    IF jsonb_typeof(step_up) != 'object' THEN
        RETURN false;
    END IF;

    IF step_up = '{}'::jsonb THEN
        RETURN false;
    END IF;

    FOR v_key, v_value IN SELECT key, value FROM jsonb_each(step_up) LOOP
        IF v_key NOT IN ('INSERT', 'UPDATE', 'DELETE') THEN
            RETURN false;
        END IF;

        -- A list of guards: every element is an object that would be valid
        -- on its own, and carries a name no sibling shares (one may go
        -- unnamed: the verb's default guard).
        IF jsonb_typeof(v_value) = 'array' THEN
            IF jsonb_array_length(v_value) = 0 THEN
                RETURN false;
            END IF;
            v_guard_names := ARRAY[]::text[];
            FOR v_guard IN SELECT elem FROM jsonb_array_elements(v_value) AS g(elem) LOOP
                IF jsonb_typeof(v_guard) != 'object' THEN
                    RETURN false;
                END IF;
                IF v_guard ? 'name' THEN
                    IF jsonb_typeof(v_guard -> 'name') != 'string'
                       OR (v_guard ->> 'name') !~ '^[a-z][a-z0-9_]*$' THEN
                        RETURN false;
                    END IF;
                END IF;
                IF COALESCE(v_guard ->> 'name', '') = ANY(v_guard_names) THEN
                    RETURN false;
                END IF;
                v_guard_names := v_guard_names || COALESCE(v_guard ->> 'name', '');
                IF NOT metaschema_private.is_valid_step_up(jsonb_build_object(v_key, v_guard - 'name')) THEN
                    RETURN false;
                END IF;
            END LOOP;
            CONTINUE;
        END IF;

        IF jsonb_typeof(v_value) = 'boolean' THEN
            IF v_value = 'false'::jsonb THEN
                RETURN false;
            END IF;
        ELSIF jsonb_typeof(v_value) = 'string' THEN
            IF v_value #>> '{}' NOT IN ('password', 'mfa', 'fresh_auth', 'password_or_mfa') THEN
                RETURN false;
            END IF;
        ELSIF jsonb_typeof(v_value) = 'object' THEN
            IF v_value = '{}'::jsonb THEN
                RETURN false;
            END IF;

            FOR v_obj_key IN SELECT key FROM jsonb_each(v_value) LOOP
                IF v_obj_key NOT IN ('type', 'min_age', 'min_age_lookup', 'min_age_anchor', 'min_age_unless', 'allow_system', 'conditions', 'related_conditions') THEN
                    RETURN false;
                END IF;
            END LOOP;

            v_type := v_value -> 'type';
            IF v_type IS NOT NULL THEN
                IF jsonb_typeof(v_type) != 'string'
                   OR v_type #>> '{}' NOT IN ('password', 'mfa', 'fresh_auth', 'password_or_mfa') THEN
                    RETURN false;
                END IF;
            END IF;

            v_min_age := v_value -> 'min_age';
            IF v_min_age IS NOT NULL THEN
                -- min_age is meaningless for INSERT: a new row has no age
                IF v_key = 'INSERT' THEN
                    RETURN false;
                END IF;

                IF jsonb_typeof(v_min_age) != 'string' THEN
                    RETURN false;
                END IF;

                BEGIN
                    v_min_age_interval := (v_min_age #>> '{}')::interval;
                EXCEPTION WHEN OTHERS THEN
                    RETURN false;
                END;

                IF v_min_age_interval <= interval '0' THEN
                    RETURN false;
                END IF;
            END IF;

            v_min_age_lookup := v_value -> 'min_age_lookup';
            IF v_min_age_lookup IS NOT NULL THEN
                -- lookup windows are meaningless for INSERT and need min_age
                -- as the fallback default
                IF v_key = 'INSERT' OR v_min_age IS NULL THEN
                    RETURN false;
                END IF;

                IF jsonb_typeof(v_min_age_lookup) != 'object' THEN
                    RETURN false;
                END IF;

                FOR v_lookup_key IN SELECT key FROM jsonb_each(v_min_age_lookup) LOOP
                    IF v_lookup_key NOT IN ('table_id', 'fk_field', 'min_age_field') THEN
                        RETURN false;
                    END IF;
                END LOOP;

                IF jsonb_typeof(v_min_age_lookup -> 'table_id') IS DISTINCT FROM 'string'
                   OR jsonb_typeof(v_min_age_lookup -> 'fk_field') IS DISTINCT FROM 'string'
                   OR jsonb_typeof(v_min_age_lookup -> 'min_age_field') IS DISTINCT FROM 'string' THEN
                    RETURN false;
                END IF;

                BEGIN
                    v_lookup_table_id := (v_min_age_lookup ->> 'table_id')::uuid;
                EXCEPTION WHEN OTHERS THEN
                    RETURN false;
                END;
            END IF;

            v_min_age_anchor := v_value -> 'min_age_anchor';
            IF v_min_age_anchor IS NOT NULL THEN
                -- an anchor says where the window is measured from, so it
                -- needs a window, and INSERT has no window at all
                IF v_key = 'INSERT' OR v_min_age IS NULL THEN
                    RETURN false;
                END IF;

                -- the two are alternative sources for the same window
                IF v_min_age_lookup IS NOT NULL THEN
                    RETURN false;
                END IF;

                IF jsonb_typeof(v_min_age_anchor) != 'object' THEN
                    RETURN false;
                END IF;

                FOR v_anchor_key IN SELECT key FROM jsonb_each(v_min_age_anchor) LOOP
                    IF v_anchor_key NOT IN ('table_id', 'fk_field', 'timestamp_field') THEN
                        RETURN false;
                    END IF;
                END LOOP;

                IF jsonb_typeof(v_min_age_anchor -> 'table_id') IS DISTINCT FROM 'string'
                   OR jsonb_typeof(v_min_age_anchor -> 'fk_field') IS DISTINCT FROM 'string'
                   OR jsonb_typeof(v_min_age_anchor -> 'timestamp_field') IS DISTINCT FROM 'string' THEN
                    RETURN false;
                END IF;

                BEGIN
                    v_anchor_table_id := (v_min_age_anchor ->> 'table_id')::uuid;
                EXCEPTION WHEN OTHERS THEN
                    RETURN false;
                END;
            END IF;

            v_min_age_unless := v_value -> 'min_age_unless';
            IF v_min_age_unless IS NOT NULL THEN
                -- forfeiting a grace needs a grace to forfeit, and only a
                -- static window can be forfeited
                IF v_key = 'INSERT' OR v_min_age IS NULL
                   OR v_min_age_lookup IS NOT NULL OR v_min_age_anchor IS NOT NULL THEN
                    RETURN false;
                END IF;

                IF NOT metaschema_private.is_valid_step_up_conditions(v_min_age_unless) THEN
                    RETURN false;
                END IF;
            END IF;

            v_allow_system := v_value -> 'allow_system';
            IF v_allow_system IS NOT NULL THEN
                IF jsonb_typeof(v_allow_system) != 'boolean' THEN
                    RETURN false;
                END IF;
            END IF;

            v_conditions := v_value -> 'conditions';
            IF v_conditions IS NOT NULL THEN
                IF NOT metaschema_private.is_valid_step_up_conditions(v_conditions) THEN
                    RETURN false;
                END IF;
            END IF;

            v_related_conditions := v_value -> 'related_conditions';
            IF v_related_conditions IS NOT NULL THEN
                -- the body belongs to one mechanism: a lookup or anchored
                -- window already occupies it
                IF v_min_age_lookup IS NOT NULL OR v_min_age_anchor IS NOT NULL THEN
                    RETURN false;
                END IF;

                IF jsonb_typeof(v_related_conditions) != 'object' THEN
                    RETURN false;
                END IF;

                FOR v_related_key IN SELECT key FROM jsonb_each(v_related_conditions) LOOP
                    IF v_related_key NOT IN ('table_id', 'fk_field', 'conditions') THEN
                        RETURN false;
                    END IF;
                END LOOP;

                IF jsonb_typeof(v_related_conditions -> 'table_id') IS DISTINCT FROM 'string'
                   OR jsonb_typeof(v_related_conditions -> 'fk_field') IS DISTINCT FROM 'string' THEN
                    RETURN false;
                END IF;

                BEGIN
                    v_related_table_id := (v_related_conditions ->> 'table_id')::uuid;
                EXCEPTION WHEN OTHERS THEN
                    RETURN false;
                END;

                IF NOT metaschema_private.is_valid_step_up_conditions(v_related_conditions -> 'conditions') THEN
                    RETURN false;
                END IF;
            END IF;
        ELSE
            RETURN false;
        END IF;
    END LOOP;

    RETURN true;
END;
$$
LANGUAGE 'plpgsql' IMMUTABLE;

COMMIT;
