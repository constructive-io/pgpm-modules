-- Deploy schemas/infra_utils/procedures/resource_admission to pg

-- requires: schemas/infra_utils/schema
-- requires: errors:schemas/errors/procedures/raise_error

BEGIN;

-- ============================================================================
-- DB-driven Kubernetes resource admission
-- ============================================================================
-- Pure evaluators for the table-driven admission gate on resources /
-- resource_definitions. The generated BEFORE INSERT/UPDATE trigger reads the
-- scope's policy tables (k8s_resource_kinds / k8s_spec_rules) and hands the
-- kind policy + enabled rules here, so all enforcement semantics live in one
-- reviewable, unit-testable place while table names stay a generator concern.
--
-- The model is fail-closed: a kind with no active policy row is denied, a
-- disabled kind is denied, a scope mismatch is denied, and a rule whose
-- rule_type is unknown raises instead of being skipped.

-- True when target_key appears as an object key anywhere in doc (any depth,
-- descending through both objects and arrays).
CREATE FUNCTION infra_utils.jsonb_has_key_deep(
  doc jsonb,
  target_key text
) RETURNS boolean AS $$
DECLARE
  doc_type text;
BEGIN
  doc_type := jsonb_typeof(doc);

  IF doc_type = 'object' THEN
    IF doc ? target_key THEN
      RETURN true;
    END IF;
    RETURN EXISTS (
      SELECT 1 FROM jsonb_each(doc) AS kv
      WHERE infra_utils.jsonb_has_key_deep(kv.value, target_key)
    );
  ELSIF doc_type = 'array' THEN
    RETURN EXISTS (
      SELECT 1 FROM jsonb_array_elements(doc) AS el
      WHERE infra_utils.jsonb_has_key_deep(el.value, target_key)
    );
  END IF;

  RETURN false;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Admission check for one resource write.
--
--   resource_kind  the row's kind (e.g. 'Deployment')
--   resource_slug  the row's slug (error context only)
--   spec           the jsonb under admission (resources.spec or
--                  resource_definitions.default_spec)
--   kind_policy    the matching k8s_resource_kinds definition (with its slug
--                  merged in), or NULL when no active row exists. A policy
--                  with spec_is_manifest=true declares that the kind's spec
--                  carries whole Kubernetes documents rather than this
--                  platform's projected-spec vocabulary, so the kind-agnostic
--                  rules (written against that vocabulary) do not apply to
--                  it; rules naming the kind still do.
--   spec_rules     jsonb array of active k8s_spec_rules definitions, each with
--                  its slug merged in
--   scope_label    the scope the tables were generated at ('platform',
--                  'database', ...)
--
-- Rule definition shapes (rule_type → match):
--   banned_key                {"key": text}          key present at any depth
--   banned_path               {"path": [text, ...]}  value present at path
--   banned_env_value          {}                     spec.env[*] entry carries
--                                                    a literal "value"
--   allowed_value             {"path": [...], "values": [text, ...]}
--                                                    value at path must be one
--                                                    of values (when present)
--   platform_only             {"path": [...], "value": text}
--                                                    value at path may equal
--                                                    value only at platform
--                                                    scope
--   allowed_annotation_prefix {"prefix": text}       when any such rule
--                                                    matches the kind, every
--                                                    spec.annotations key must
--                                                    start with an allowed
--                                                    prefix
CREATE FUNCTION infra_utils.check_resource_admission(
  resource_kind text,
  resource_slug text,
  spec jsonb,
  kind_policy jsonb,
  spec_rules jsonb,
  scope_label text
) RETURNS void AS $$
DECLARE
  rule jsonb;
  rule_type text;
  rule_match jsonb;
  match_path text[];
  match_value text;

  -- Allowed annotation prefixes accumulated across matching rules; a non-empty
  -- set turns on the annotations allow-list for this kind.
  annotation_prefixes text[] := ARRAY[]::text[];
  annotation_key text;
  prefix_ok boolean;
  prefix text;
BEGIN
  -- ---------------------------------------------------------------------
  -- Kind gate (fail closed)
  -- ---------------------------------------------------------------------
  IF kind_policy IS NULL THEN
    PERFORM errors.raise_error(
      'RESOURCE_KIND_NOT_ALLOWED',
      jsonb_build_object(
        'kind', resource_kind,
        'slug', resource_slug,
        'reason', 'no active kind policy exists for this kind'
      ),
      'public'
    );
  END IF;

  IF NOT COALESCE((kind_policy->>'allowed')::boolean, false) THEN
    PERFORM errors.raise_error(
      'RESOURCE_KIND_NOT_ALLOWED',
      jsonb_build_object(
        'kind', resource_kind,
        'slug', resource_slug,
        'reason', 'kind is disabled by policy'
      ),
      'public'
    );
  END IF;

  IF kind_policy ? 'allowed_scopes'
     AND NOT (kind_policy->'allowed_scopes' ? scope_label) THEN
    PERFORM errors.raise_error(
      'RESOURCE_KIND_NOT_ALLOWED',
      jsonb_build_object(
        'kind', resource_kind,
        'slug', resource_slug,
        'scope', scope_label,
        'reason', 'kind is not allowed at this scope'
      ),
      'public'
    );
  END IF;

  -- ---------------------------------------------------------------------
  -- Spec rules
  -- ---------------------------------------------------------------------
  FOR rule IN SELECT value FROM jsonb_array_elements(COALESCE(spec_rules, '[]'::jsonb)) LOOP
    -- A rule with no kind applies to every kind; otherwise only to its own.
    IF rule->>'kind' IS NOT NULL AND rule->>'kind' <> resource_kind THEN
      CONTINUE;
    END IF;
    IF rule->>'kind' IS NULL
       AND COALESCE((kind_policy->>'spec_is_manifest')::boolean, false) THEN
      CONTINUE;
    END IF;

    rule_type := rule->>'rule_type';
    rule_match := COALESCE(rule->'match', '{}'::jsonb);

    IF rule_type = 'banned_key' THEN
      -- A malformed rule must never widen what a tenant can write, so missing
      -- match fields raise instead of matching nothing (same for every rule
      -- type below).
      IF rule_match->>'key' IS NULL THEN
        PERFORM errors.raise_error(
          'RESOURCE_ADMISSION_RULE_INVALID',
          jsonb_build_object('rule', rule->>'slug', 'rule_type', rule_type, 'reason', 'match.key is required'),
          'internal'
        );
      END IF;
      IF infra_utils.jsonb_has_key_deep(spec, rule_match->>'key') THEN
        PERFORM errors.raise_error(
          'RESOURCE_SPEC_NOT_ALLOWED',
          jsonb_build_object(
            'kind', resource_kind,
            'slug', resource_slug,
            'rule', rule->>'slug',
            'key', rule_match->>'key'
          ),
          'public'
        );
      END IF;

    ELSIF rule_type = 'banned_path' THEN
      IF jsonb_typeof(rule_match->'path') IS DISTINCT FROM 'array' THEN
        PERFORM errors.raise_error(
          'RESOURCE_ADMISSION_RULE_INVALID',
          jsonb_build_object('rule', rule->>'slug', 'rule_type', rule_type, 'reason', 'match.path must be an array'),
          'internal'
        );
      END IF;
      match_path := ARRAY(SELECT jsonb_array_elements_text(rule_match->'path'));
      IF spec #> match_path IS NOT NULL THEN
        PERFORM errors.raise_error(
          'RESOURCE_SPEC_NOT_ALLOWED',
          jsonb_build_object(
            'kind', resource_kind,
            'slug', resource_slug,
            'rule', rule->>'slug',
            'path', rule_match->'path'
          ),
          'public'
        );
      END IF;

    ELSIF rule_type = 'banned_env_value' THEN
      IF EXISTS (
        SELECT 1
        FROM jsonb_array_elements(
          CASE WHEN jsonb_typeof(spec->'env') = 'array'
               THEN spec->'env' ELSE '[]'::jsonb END
        ) AS env_entry
        WHERE env_entry.value ? 'value'
      ) THEN
        PERFORM errors.raise_error(
          'RESOURCE_SPEC_NOT_ALLOWED',
          jsonb_build_object(
            'kind', resource_kind,
            'slug', resource_slug,
            'rule', rule->>'slug',
            'reason', 'literal env values are not allowed; reference required_secrets/required_configs instead'
          ),
          'public'
        );
      END IF;

    ELSIF rule_type = 'allowed_value' THEN
      IF jsonb_typeof(rule_match->'path') IS DISTINCT FROM 'array'
         OR jsonb_typeof(rule_match->'values') IS DISTINCT FROM 'array' THEN
        PERFORM errors.raise_error(
          'RESOURCE_ADMISSION_RULE_INVALID',
          jsonb_build_object('rule', rule->>'slug', 'rule_type', rule_type, 'reason', 'match.path and match.values must be arrays'),
          'internal'
        );
      END IF;
      match_path := ARRAY(SELECT jsonb_array_elements_text(rule_match->'path'));
      match_value := spec #>> match_path;
      IF match_value IS NOT NULL
         AND NOT (rule_match->'values' ? match_value) THEN
        PERFORM errors.raise_error(
          'RESOURCE_SPEC_NOT_ALLOWED',
          jsonb_build_object(
            'kind', resource_kind,
            'slug', resource_slug,
            'rule', rule->>'slug',
            'path', rule_match->'path',
            'value', match_value,
            'allowed', rule_match->'values'
          ),
          'public'
        );
      END IF;

    ELSIF rule_type = 'platform_only' THEN
      IF jsonb_typeof(rule_match->'path') IS DISTINCT FROM 'array'
         OR rule_match->>'value' IS NULL THEN
        PERFORM errors.raise_error(
          'RESOURCE_ADMISSION_RULE_INVALID',
          jsonb_build_object('rule', rule->>'slug', 'rule_type', rule_type, 'reason', 'match.path must be an array and match.value is required'),
          'internal'
        );
      END IF;
      match_path := ARRAY(SELECT jsonb_array_elements_text(rule_match->'path'));
      match_value := spec #>> match_path;
      IF match_value IS NOT DISTINCT FROM rule_match->>'value'
         AND scope_label <> 'platform' THEN
        PERFORM errors.raise_error(
          'RESOURCE_SPEC_NOT_ALLOWED',
          jsonb_build_object(
            'kind', resource_kind,
            'slug', resource_slug,
            'rule', rule->>'slug',
            'path', rule_match->'path',
            'value', match_value,
            'reason', 'value is reserved for platform scope'
          ),
          'public'
        );
      END IF;

    ELSIF rule_type = 'allowed_annotation_prefix' THEN
      -- An empty prefix would match every annotation key and turn the
      -- allow-list into a no-op.
      IF COALESCE(rule_match->>'prefix', '') = '' THEN
        PERFORM errors.raise_error(
          'RESOURCE_ADMISSION_RULE_INVALID',
          jsonb_build_object('rule', rule->>'slug', 'rule_type', rule_type, 'reason', 'match.prefix must be a non-empty string'),
          'internal'
        );
      END IF;
      annotation_prefixes := array_append(annotation_prefixes, rule_match->>'prefix');

    ELSE
      -- Unknown rule types deny rather than silently pass: a typo in a rule
      -- must never widen what a tenant can write.
      PERFORM errors.raise_error(
        'RESOURCE_ADMISSION_RULE_INVALID',
        jsonb_build_object(
          'rule', rule->>'slug',
          'rule_type', rule_type
        ),
        'internal'
      );
    END IF;
  END LOOP;

  -- ---------------------------------------------------------------------
  -- Annotation prefix allow-list (only when rules declared one for this kind)
  -- ---------------------------------------------------------------------
  IF array_length(annotation_prefixes, 1) IS NOT NULL
     AND jsonb_typeof(spec->'annotations') = 'object' THEN
    FOR annotation_key IN SELECT jsonb_object_keys(spec->'annotations') LOOP
      prefix_ok := false;
      FOREACH prefix IN ARRAY annotation_prefixes LOOP
        IF prefix IS NOT NULL AND left(annotation_key, length(prefix)) = prefix THEN
          prefix_ok := true;
        END IF;
      END LOOP;
      IF NOT prefix_ok THEN
        PERFORM errors.raise_error(
          'RESOURCE_SPEC_NOT_ALLOWED',
          jsonb_build_object(
            'kind', resource_kind,
            'slug', resource_slug,
            'annotation', annotation_key,
            'allowed_prefixes', to_jsonb(annotation_prefixes),
            'reason', 'annotation key does not match an allowed prefix'
          ),
          'public'
        );
      END IF;
    END LOOP;
  END IF;
END;
$$ LANGUAGE plpgsql VOLATILE;

COMMIT;
