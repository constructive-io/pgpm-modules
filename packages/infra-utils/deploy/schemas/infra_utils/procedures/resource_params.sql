-- Deploy schemas/infra_utils/procedures/resource_params to pg

-- requires: schemas/infra_utils/schema
-- requires: db-utils:schemas/db_utils/procedures/jsonb_deep_merge
-- requires: db-utils:schemas/db_utils/procedures/jsonb_set_deep
-- requires: schemas/infra_utils/procedures/param_quantity

BEGIN;

-- ============================================================================
-- Declared parameter interfaces for resource definitions ("digital assets")
-- ============================================================================
-- A resource definition is a node with a default spec; a bundle of definitions
-- installed together is the asset. Its PUBLIC interface is a declared list of
-- typed parameters, each bound to the exact spec paths it may write — the
-- parameter-template + promotion model, expressed as data:
--
--   [
--     {
--       "key": "heap_mb",              -- public parameter name (bundle-wide)
--       "type": "int",                 -- int | text | bool | enum | quantity
--       "label": "Heap size (MB)",
--       "description": "Node.js old-space size for the server",
--       "default": 3072,
--       "required": false,             -- required params carry no default
--       "min": 512, "max": 16384,      -- int/quantity only
--       "options": ["a", "b"],         -- enum only
--       "group": "Resources", "order": 10,
--       "bindings": [
--         { "path": "settings.NODE_OPTIONS",
--           "template": "--max-old-space-size={{value}}" },
--         { "path": "resources.limits.memory",
--           "scale": 1.34, "round": "ceil", "unit": "Mi" }
--       ]
--     }
--   ]
--
-- Two properties matter and are the whole point of declaring the interface:
--
--   1. Writes are BOUNDED. Compilation is "for each declared parameter, write
--      its typed value at its declared paths" — not "deep-merge two blobs". A
--      key nobody declared cannot reach a spec, and a typo fails loudly.
--   2. Derived values stay COHERENT. One parameter may drive several paths
--      (`heap_mb` sets both the Node flag and the memory limit), so a heap
--      larger than its container limit is not expressible.
--
-- Definitions that declare no parameters keep the historical behaviour (a deep
-- merge of the raw params blob), so hand-made members and pre-interface bundles
-- keep working unchanged.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Declaration well-formedness. Raised errors are authoring errors (internal):
-- a malformed interface is a bug in the bundle, not bad user input.
-- ----------------------------------------------------------------------------
CREATE FUNCTION infra_utils.validate_params_schema(params_schema jsonb) RETURNS void AS $$
DECLARE
  declaration jsonb;
  binding jsonb;
  seen_keys text[] := ARRAY[]::text[];
  param_key text;
  param_type text;
  path_parts text[];
BEGIN
  IF params_schema IS NULL OR params_schema = 'null'::jsonb THEN
    RETURN;
  END IF;

  IF jsonb_typeof(params_schema) <> 'array' THEN
    PERFORM errors.raise_error(
      'RESOURCE_PARAM_SCHEMA_INVALID',
      jsonb_build_object('reason', 'params_schema must be a JSON array of declarations'),
      'internal'
    );
  END IF;

  FOR declaration IN SELECT * FROM jsonb_array_elements(params_schema) LOOP
    IF jsonb_typeof(declaration) <> 'object' THEN
      PERFORM errors.raise_error(
        'RESOURCE_PARAM_SCHEMA_INVALID',
        jsonb_build_object('reason', 'each parameter declaration must be an object'),
        'internal'
      );
    END IF;

    param_key := declaration ->> 'key';
    param_type := declaration ->> 'type';

    IF param_key IS NULL OR param_key !~ '^[a-z][a-z0-9_]*$' THEN
      PERFORM errors.raise_error(
        'RESOURCE_PARAM_SCHEMA_INVALID',
        jsonb_build_object('reason', 'parameter key must match ^[a-z][a-z0-9_]*$', 'key', param_key),
        'internal'
      );
    END IF;

    -- `members` addresses a member's overlay in the params object, so it can
    -- never also be a parameter name.
    IF param_key = 'members' THEN
      PERFORM errors.raise_error(
        'RESOURCE_PARAM_SCHEMA_INVALID',
        jsonb_build_object('reason', '"members" is reserved and cannot be a parameter key'),
        'internal'
      );
    END IF;

    IF param_key = ANY (seen_keys) THEN
      PERFORM errors.raise_error(
        'RESOURCE_PARAM_SCHEMA_INVALID',
        jsonb_build_object('reason', 'duplicate parameter key', 'key', param_key),
        'internal'
      );
    END IF;
    seen_keys := seen_keys || param_key;

    IF param_type IS NULL OR param_type NOT IN ('int', 'text', 'bool', 'enum', 'quantity') THEN
      PERFORM errors.raise_error(
        'RESOURCE_PARAM_SCHEMA_INVALID',
        jsonb_build_object(
          'reason', 'parameter type must be one of int, text, bool, enum, quantity',
          'key', param_key, 'type', param_type
        ),
        'internal'
      );
    END IF;

    IF param_type = 'enum' THEN
      IF COALESCE(jsonb_typeof(declaration -> 'options'), 'missing') <> 'array'
         OR jsonb_array_length(declaration -> 'options') = 0 THEN
        PERFORM errors.raise_error(
          'RESOURCE_PARAM_SCHEMA_INVALID',
          jsonb_build_object('reason', 'enum parameters require a non-empty options array', 'key', param_key),
          'internal'
        );
      END IF;
    ELSIF declaration ? 'options' THEN
      PERFORM errors.raise_error(
        'RESOURCE_PARAM_SCHEMA_INVALID',
        jsonb_build_object('reason', 'options is only valid for enum parameters', 'key', param_key),
        'internal'
      );
    END IF;

    IF (declaration ? 'min' OR declaration ? 'max') AND param_type NOT IN ('int', 'quantity') THEN
      PERFORM errors.raise_error(
        'RESOURCE_PARAM_SCHEMA_INVALID',
        jsonb_build_object('reason', 'min/max are only valid for int and quantity parameters', 'key', param_key),
        'internal'
      );
    END IF;

    -- A required parameter must be supplied by the caller, so a default would
    -- make "required" unobservable.
    IF COALESCE((declaration -> 'required')::boolean, false) AND declaration ? 'default' THEN
      PERFORM errors.raise_error(
        'RESOURCE_PARAM_SCHEMA_INVALID',
        jsonb_build_object('reason', 'a required parameter cannot also declare a default', 'key', param_key),
        'internal'
      );
    END IF;

    IF COALESCE(jsonb_typeof(declaration -> 'bindings'), 'missing') <> 'array'
       OR jsonb_array_length(declaration -> 'bindings') = 0 THEN
      PERFORM errors.raise_error(
        'RESOURCE_PARAM_SCHEMA_INVALID',
        jsonb_build_object(
          'reason', 'each parameter must declare at least one binding (where it writes)',
          'key', param_key
        ),
        'internal'
      );
    END IF;

    FOR binding IN SELECT * FROM jsonb_array_elements(declaration -> 'bindings') LOOP
      IF jsonb_typeof(binding) <> 'object' OR (binding ->> 'path') IS NULL THEN
        PERFORM errors.raise_error(
          'RESOURCE_PARAM_SCHEMA_INVALID',
          jsonb_build_object('reason', 'each binding must be an object with a path', 'key', param_key),
          'internal'
        );
      END IF;

      path_parts := string_to_array(binding ->> 'path', '.');
      IF array_length(path_parts, 1) IS NULL OR '' = ANY (path_parts) THEN
        PERFORM errors.raise_error(
          'RESOURCE_PARAM_SCHEMA_INVALID',
          jsonb_build_object(
            'reason', 'binding path must be dot-separated non-empty segments',
            'key', param_key, 'path', binding ->> 'path'
          ),
          'internal'
        );
      END IF;

      IF binding ? 'template' AND binding ? 'scale' THEN
        PERFORM errors.raise_error(
          'RESOURCE_PARAM_SCHEMA_INVALID',
          jsonb_build_object('reason', 'a binding may declare template or scale, not both', 'key', param_key),
          'internal'
        );
      END IF;

      IF binding ? 'template' AND position('{{value}}' in (binding ->> 'template')) = 0 THEN
        PERFORM errors.raise_error(
          'RESOURCE_PARAM_SCHEMA_INVALID',
          jsonb_build_object(
            'reason', 'a binding template must interpolate {{value}}',
            'key', param_key, 'template', binding ->> 'template'
          ),
          'internal'
        );
      END IF;

      -- `scale` derives a second numeric value from a numeric parameter (heap
      -- MB -> container memory limit). Scaling a quantity's magnitude would
      -- silently reinterpret its suffix, so it is restricted to int.
      IF binding ? 'scale' THEN
        IF param_type <> 'int' THEN
          PERFORM errors.raise_error(
            'RESOURCE_PARAM_SCHEMA_INVALID',
            jsonb_build_object('reason', 'scale bindings are only valid for int parameters', 'key', param_key),
            'internal'
          );
        END IF;
        IF jsonb_typeof(binding -> 'scale') <> 'number' OR (binding -> 'scale')::numeric <= 0 THEN
          PERFORM errors.raise_error(
            'RESOURCE_PARAM_SCHEMA_INVALID',
            jsonb_build_object('reason', 'scale must be a positive number', 'key', param_key),
            'internal'
          );
        END IF;
      END IF;

      IF binding ? 'round' AND (binding ->> 'round') NOT IN ('ceil', 'floor', 'round') THEN
        PERFORM errors.raise_error(
          'RESOURCE_PARAM_SCHEMA_INVALID',
          jsonb_build_object(
            'reason', 'round must be one of ceil, floor, round',
            'key', param_key, 'round', binding ->> 'round'
          ),
          'internal'
        );
      END IF;
    END LOOP;

    -- A declared default is a value like any other: it must satisfy the
    -- declaration it belongs to.
    IF declaration ? 'default' THEN
      PERFORM infra_utils.coerce_param_value(declaration, declaration -> 'default');
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql VOLATILE;

-- ----------------------------------------------------------------------------
-- Interface evolution: a key's TYPE is immutable for the life of the key.
-- Retyping (text -> quantity) would silently reinterpret every value already
-- committed in merkle history, making old revisions un-rollback-able; adding,
-- removing and re-defaulting keys stay free.
-- ----------------------------------------------------------------------------
CREATE FUNCTION infra_utils.validate_params_schema_change(
  old_schema jsonb,
  new_schema jsonb
) RETURNS void AS $$
DECLARE
  conflict record;
BEGIN
  IF old_schema IS NULL OR new_schema IS NULL THEN
    RETURN;
  END IF;
  IF jsonb_typeof(old_schema) <> 'array' OR jsonb_typeof(new_schema) <> 'array' THEN
    RETURN;
  END IF;

  SELECT o.key AS param_key, o.type AS old_type, n.type AS new_type
    INTO conflict
    FROM jsonb_to_recordset(old_schema) AS o(key text, type text)
    JOIN jsonb_to_recordset(new_schema) AS n(key text, type text)
      ON n.key = o.key
   WHERE n.type IS DISTINCT FROM o.type
   LIMIT 1;

  IF conflict.param_key IS NOT NULL THEN
    PERFORM errors.raise_error(
      'RESOURCE_PARAM_RETYPED',
      jsonb_build_object(
        'reason', 'a declared parameter cannot change type; declare a new key instead',
        'key', conflict.param_key,
        'old_type', conflict.old_type,
        'new_type', conflict.new_type
      ),
      'internal'
    );
  END IF;
END;
$$ LANGUAGE plpgsql VOLATILE;

-- ----------------------------------------------------------------------------
-- Type + constraint check for one supplied value. Errors here are user-facing:
-- someone asked for a value the interface does not accept.
-- ----------------------------------------------------------------------------
CREATE FUNCTION infra_utils.coerce_param_value(
  declaration jsonb,
  value jsonb
) RETURNS jsonb AS $$
DECLARE
  param_key text := declaration ->> 'key';
  param_type text := declaration ->> 'type';
  value_type text := jsonb_typeof(value);
  magnitude numeric;
BEGIN
  IF param_type = 'int' THEN
    IF value_type <> 'number' OR (value)::numeric <> trunc((value)::numeric) THEN
      PERFORM errors.raise_error(
        'RESOURCE_PARAM_INVALID',
        jsonb_build_object('reason', 'expected an integer', 'key', param_key, 'value', value),
        'public'
      );
    END IF;
    magnitude := (value)::numeric;

  ELSIF param_type = 'bool' THEN
    IF value_type <> 'boolean' THEN
      PERFORM errors.raise_error(
        'RESOURCE_PARAM_INVALID',
        jsonb_build_object('reason', 'expected a boolean', 'key', param_key, 'value', value),
        'public'
      );
    END IF;

  ELSIF param_type = 'text' THEN
    IF value_type <> 'string' THEN
      PERFORM errors.raise_error(
        'RESOURCE_PARAM_INVALID',
        jsonb_build_object('reason', 'expected a string', 'key', param_key, 'value', value),
        'public'
      );
    END IF;

  ELSIF param_type = 'enum' THEN
    IF value_type <> 'string' OR NOT (declaration -> 'options') @> jsonb_build_array(value #>> '{}') THEN
      PERFORM errors.raise_error(
        'RESOURCE_PARAM_INVALID',
        jsonb_build_object(
          'reason', 'value is not one of the declared options',
          'key', param_key, 'value', value, 'options', declaration -> 'options'
        ),
        'public'
      );
    END IF;

  ELSIF param_type = 'quantity' THEN
    IF value_type <> 'string' OR infra_utils.quantity_to_numeric(value #>> '{}') IS NULL THEN
      PERFORM errors.raise_error(
        'RESOURCE_PARAM_INVALID',
        jsonb_build_object(
          'reason', 'expected a Kubernetes quantity such as 4Gi, 512Mi or 500m',
          'key', param_key, 'value', value
        ),
        'public'
      );
    END IF;
    magnitude := infra_utils.quantity_to_numeric(value #>> '{}');
  END IF;

  IF magnitude IS NOT NULL AND declaration ? 'min' THEN
    IF magnitude < infra_utils.param_bound_magnitude(param_type, declaration -> 'min') THEN
      PERFORM errors.raise_error(
        'RESOURCE_PARAM_INVALID',
        jsonb_build_object(
          'reason', 'value is below the declared minimum',
          'key', param_key, 'value', value, 'min', declaration -> 'min'
        ),
        'public'
      );
    END IF;
  END IF;

  IF magnitude IS NOT NULL AND declaration ? 'max' THEN
    IF magnitude > infra_utils.param_bound_magnitude(param_type, declaration -> 'max') THEN
      PERFORM errors.raise_error(
        'RESOURCE_PARAM_INVALID',
        jsonb_build_object(
          'reason', 'value is above the declared maximum',
          'key', param_key, 'value', value, 'max', declaration -> 'max'
        ),
        'public'
      );
    END IF;
  END IF;

  RETURN value;
END;
$$ LANGUAGE plpgsql VOLATILE;

-- A bound is written in the parameter's own notation: a number for int, a
-- quantity string for quantity.
CREATE FUNCTION infra_utils.param_bound_magnitude(
  param_type text,
  bound jsonb
) RETURNS numeric AS $$
  SELECT CASE
    WHEN bound IS NULL THEN NULL
    WHEN param_type = 'quantity' AND jsonb_typeof(bound) = 'string'
      THEN infra_utils.quantity_to_numeric(bound #>> '{}')
    WHEN jsonb_typeof(bound) = 'number' THEN (bound)::numeric
    ELSE NULL
  END;
$$ LANGUAGE sql IMMUTABLE;

-- ----------------------------------------------------------------------------
-- Render one binding's value: the parameter value itself, a template around it
-- (`--max-old-space-size={{value}}`), or a scaled derivation of it
-- (`heap_mb` * 1.34 rounded up, suffixed `Mi`).
-- ----------------------------------------------------------------------------
CREATE FUNCTION infra_utils.render_param_binding(
  binding jsonb,
  value jsonb
) RETURNS jsonb AS $$
DECLARE
  value_text text := value #>> '{}';
  scaled numeric;
  rounded numeric;
BEGIN
  IF binding ? 'template' THEN
    RETURN to_jsonb(replace(binding ->> 'template', '{{value}}', value_text));
  END IF;

  IF binding ? 'scale' THEN
    scaled := (value)::numeric * (binding -> 'scale')::numeric;
    rounded := CASE COALESCE(binding ->> 'round', 'ceil')
      WHEN 'floor' THEN floor(scaled)
      WHEN 'round' THEN round(scaled)
      ELSE ceil(scaled)
    END;
    IF binding ? 'unit' THEN
      RETURN to_jsonb(rounded::bigint::text || (binding ->> 'unit'));
    END IF;
    RETURN to_jsonb(rounded::bigint);
  END IF;

  RETURN value;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ----------------------------------------------------------------------------
-- Compile one member's effective spec.
--
--   compile_resource_spec(default_spec, params_schema, params, member_slug,
--                         bundle_schemas)
--
-- With a declared interface this is a bounded set of writes onto the
-- definition's default spec: every declared parameter resolves to a value
-- (member override -> bundle-wide value -> declared default) and lands only at
-- its declared paths. A parameter that is neither supplied nor defaulted writes
-- nothing, so the definition's own default spec still shows through — which is
-- what makes "drop a parameter and the default returns" true.
--
-- With no declared interface the historical deep merge applies, so hand-made
-- members and pre-interface bundles are unaffected.
-- ----------------------------------------------------------------------------
CREATE FUNCTION infra_utils.compile_resource_spec(
  base_spec jsonb,
  params_schema jsonb,
  params jsonb,
  member_slug text,
  bundle_schemas jsonb DEFAULT NULL
) RETURNS jsonb AS $$
DECLARE
  effective_params jsonb := COALESCE(params, '{}'::jsonb);
  member_params jsonb;
  declaration jsonb;
  binding jsonb;
  spec jsonb := COALESCE(base_spec, '{}'::jsonb);
  supplied_key text;
  param_key text;
  value jsonb;
BEGIN
  member_params := COALESCE(effective_params -> 'members' -> member_slug, '{}'::jsonb);

  IF params_schema IS NULL
     OR jsonb_typeof(params_schema) <> 'array'
     OR jsonb_array_length(params_schema) = 0 THEN
    -- This member declares nothing. In a bundle where some OTHER member does,
    -- the params object is a set of declared parameters — not raw spec fields —
    -- so overlaying it here would smear another member's parameters (heap_mb,
    -- node_env, ...) into a spec that never asked for them. Such a member is
    -- simply not parameterised: it keeps its default spec.
    IF EXISTS (
      SELECT 1 FROM jsonb_array_elements(COALESCE(bundle_schemas, '[]'::jsonb)) m
       WHERE COALESCE(jsonb_typeof(m -> 'params_schema'), 'missing') = 'array'
         AND jsonb_array_length(m -> 'params_schema') > 0
    ) THEN
      RETURN spec;
    END IF;

    RETURN db_utils.jsonb_deep_merge(
      db_utils.jsonb_deep_merge(spec, effective_params - 'members'),
      member_params
    );
  END IF;

  -- Anything addressed at this member must be a parameter this member declares:
  -- a typo fails loudly instead of silently adding a spec field.
  FOR supplied_key IN SELECT jsonb_object_keys(member_params) LOOP
    IF NOT EXISTS (
      SELECT 1 FROM jsonb_array_elements(params_schema) d
       WHERE d ->> 'key' = supplied_key
    ) THEN
      PERFORM errors.raise_error(
        'RESOURCE_PARAM_UNKNOWN',
        jsonb_build_object(
          'reason', 'member does not declare this parameter',
          'key', supplied_key, 'member', member_slug
        ),
        'public'
      );
    END IF;
  END LOOP;

  FOR declaration IN SELECT * FROM jsonb_array_elements(params_schema) LOOP
    param_key := declaration ->> 'key';

    value := CASE
      WHEN jsonb_typeof(member_params -> param_key) NOT IN ('null') AND member_params ? param_key
        THEN member_params -> param_key
      WHEN jsonb_typeof(effective_params -> param_key) NOT IN ('null') AND effective_params ? param_key
        THEN effective_params -> param_key
      ELSE NULL
    END;

    IF value IS NULL THEN
      IF COALESCE((declaration -> 'required')::boolean, false) THEN
        PERFORM errors.raise_error(
          'RESOURCE_PARAM_REQUIRED',
          jsonb_build_object('reason', 'required parameter was not supplied', 'key', param_key),
          'public'
        );
      END IF;
      IF NOT declaration ? 'default' THEN
        CONTINUE;
      END IF;
      value := declaration -> 'default';
    END IF;

    value := infra_utils.coerce_param_value(declaration, value);

    FOR binding IN SELECT * FROM jsonb_array_elements(declaration -> 'bindings') LOOP
      spec := db_utils.jsonb_set_deep(
        spec,
        string_to_array(binding ->> 'path', '.'),
        infra_utils.render_param_binding(binding, value)
      );
    END LOOP;
  END LOOP;

  RETURN spec;
END;
$$ LANGUAGE plpgsql VOLATILE;

-- ----------------------------------------------------------------------------
-- Bundle-wide validation of a params object against the members' interfaces.
--
--   schemas = [{ "slug": "graphql-private", "params_schema": [...] }, ...]
--
-- compile_resource_spec can only judge keys addressed at the member it is
-- compiling; a bundle-wide key belongs to whichever member declares it. This is
-- the one place that can therefore reject a key NO member declares, and it runs
-- once per install/upgrade/rollback before any spec is written.
--
-- A bundle whose members declare nothing keeps the untyped blob behaviour; as
-- soon as ANY member declares an interface, the bundle's params are strict.
-- ----------------------------------------------------------------------------
CREATE FUNCTION infra_utils.validate_bundle_params(
  schemas jsonb,
  params jsonb
) RETURNS void AS $$
DECLARE
  effective_params jsonb := COALESCE(params, '{}'::jsonb);
  declared_keys text[];
  member_slugs text[];
  supplied_key text;
  member_slug text;
BEGIN
  IF schemas IS NULL OR jsonb_typeof(schemas) <> 'array' OR jsonb_array_length(schemas) = 0 THEN
    RETURN;
  END IF;

  SELECT COALESCE(array_agg(DISTINCT d ->> 'key'), ARRAY[]::text[])
    INTO declared_keys
    FROM jsonb_array_elements(schemas) m
    CROSS JOIN LATERAL jsonb_array_elements(
      CASE WHEN jsonb_typeof(m -> 'params_schema') = 'array'
           THEN m -> 'params_schema' ELSE '[]'::jsonb END
    ) d;

  IF array_length(declared_keys, 1) IS NULL THEN
    RETURN;
  END IF;

  SELECT COALESCE(array_agg(m ->> 'slug'), ARRAY[]::text[])
    INTO member_slugs
    FROM jsonb_array_elements(schemas) m;

  FOR supplied_key IN SELECT jsonb_object_keys(effective_params) LOOP
    IF supplied_key = 'members' THEN
      CONTINUE;
    END IF;
    IF NOT supplied_key = ANY (declared_keys) THEN
      PERFORM errors.raise_error(
        'RESOURCE_PARAM_UNKNOWN',
        jsonb_build_object(
          'reason', 'no member of this bundle declares this parameter',
          'key', supplied_key, 'declared', to_jsonb(declared_keys)
        ),
        'public'
      );
    END IF;
  END LOOP;

  FOR member_slug IN SELECT jsonb_object_keys(COALESCE(effective_params -> 'members', '{}'::jsonb)) LOOP
    IF NOT member_slug = ANY (member_slugs) THEN
      PERFORM errors.raise_error(
        'RESOURCE_PARAM_UNKNOWN',
        jsonb_build_object(
          'reason', 'bundle has no such member',
          'member', member_slug, 'members', to_jsonb(member_slugs)
        ),
        'public'
      );
    END IF;

    FOR supplied_key IN
      SELECT jsonb_object_keys(effective_params -> 'members' -> member_slug)
    LOOP
      IF NOT EXISTS (
        SELECT 1
          FROM jsonb_array_elements(schemas) m
          CROSS JOIN LATERAL jsonb_array_elements(
            CASE WHEN jsonb_typeof(m -> 'params_schema') = 'array'
                 THEN m -> 'params_schema' ELSE '[]'::jsonb END
          ) d
         WHERE m ->> 'slug' = member_slug
           AND d ->> 'key' = supplied_key
      ) THEN
        PERFORM errors.raise_error(
          'RESOURCE_PARAM_UNKNOWN',
          jsonb_build_object(
            'reason', 'member does not declare this parameter',
            'key', supplied_key, 'member', member_slug
          ),
          'public'
        );
      END IF;
    END LOOP;
  END LOOP;
END;
$$ LANGUAGE plpgsql VOLATILE;

-- ----------------------------------------------------------------------------
-- The bundle's public interface, merged across its members — the asset's
-- parameter dialog. Two members declaring the same key share one parameter (one
-- value drives both), which is only coherent if they agree on its type.
-- ----------------------------------------------------------------------------
CREATE FUNCTION infra_utils.bundle_param_interface(schemas jsonb) RETURNS jsonb AS $$
DECLARE
  conflict record;
BEGIN
  IF schemas IS NULL OR jsonb_typeof(schemas) <> 'array' THEN
    RETURN '[]'::jsonb;
  END IF;

  SELECT d ->> 'key' AS param_key,
         count(DISTINCT d ->> 'type') AS type_count
    INTO conflict
    FROM jsonb_array_elements(schemas) m
    CROSS JOIN LATERAL jsonb_array_elements(
      CASE WHEN jsonb_typeof(m -> 'params_schema') = 'array'
           THEN m -> 'params_schema' ELSE '[]'::jsonb END
    ) d
   GROUP BY d ->> 'key'
  HAVING count(DISTINCT d ->> 'type') > 1
   LIMIT 1;

  IF conflict.param_key IS NOT NULL THEN
    PERFORM errors.raise_error(
      'RESOURCE_PARAM_CONFLICT',
      jsonb_build_object(
        'reason', 'members declare the same parameter key with different types',
        'key', conflict.param_key
      ),
      'internal'
    );
  END IF;

  RETURN COALESCE((
    SELECT jsonb_agg(
             jsonb_build_object(
               'key', param_key,
               'type', param_type,
               'label', label,
               'description', description,
               'required', required,
               'default', default_value,
               'min', min_bound,
               'max', max_bound,
               'options', options,
               'group', param_group,
               'order', param_order,
               'members', members
             )
             ORDER BY param_group NULLS FIRST, param_order NULLS LAST, param_key
           )
      FROM (
        SELECT d ->> 'key'                                          AS param_key,
               min(d ->> 'type')                                    AS param_type,
               min(d ->> 'label')                                   AS label,
               min(d ->> 'description')                             AS description,
               bool_or(COALESCE((d -> 'required')::boolean, false))  AS required,
               (array_agg(d -> 'default') FILTER (WHERE d ? 'default'))[1]  AS default_value,
               (array_agg(d -> 'min') FILTER (WHERE d ? 'min'))[1]          AS min_bound,
               (array_agg(d -> 'max') FILTER (WHERE d ? 'max'))[1]          AS max_bound,
               (array_agg(d -> 'options') FILTER (WHERE d ? 'options'))[1]  AS options,
               min(d ->> 'group')                                   AS param_group,
               min((d ->> 'order')::numeric)                        AS param_order,
               jsonb_agg(DISTINCT m ->> 'slug')                     AS members
          FROM jsonb_array_elements(schemas) m
          CROSS JOIN LATERAL jsonb_array_elements(
            CASE WHEN jsonb_typeof(m -> 'params_schema') = 'array'
                 THEN m -> 'params_schema' ELSE '[]'::jsonb END
          ) d
         GROUP BY d ->> 'key'
      ) merged
  ), '[]'::jsonb);
END;
$$ LANGUAGE plpgsql VOLATILE;

COMMIT;
