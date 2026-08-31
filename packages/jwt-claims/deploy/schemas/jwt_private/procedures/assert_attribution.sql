-- Deploy schemas/jwt_private/procedures/assert_attribution to pg
-- Raises on incomplete attribution by default; warns only when strict mode is
-- explicitly disabled. Set jwt.strict_attribution = 'false' at a boundary that
-- must tolerate incomplete attribution while its writers are being fixed.

-- requires: schemas/jwt_private/schema

BEGIN;

CREATE FUNCTION jwt_private.assert_attribution(
  actor_id uuid,
  entity_id uuid,
  entity_type text
)
  RETURNS void
AS $$
DECLARE
  strict_attribution boolean :=
    COALESCE(
      NULLIF(current_setting('jwt.strict_attribution', true), ''),
      'true'
    ) <> 'false';
  context jsonb;
BEGIN
  IF actor_id IS NULL AND entity_id IS NULL THEN
    context := jsonb_build_object(
      'arguments', jsonb_build_array('actor_id', 'entity_id'),
      'claims', jsonb_build_array('jwt.claims.user_id', 'jwt.claims.entity_id')
    );
    IF strict_attribution THEN
      PERFORM errors.raise_error('ATTRIBUTION_REQUIRED', context, 'internal');
    ELSE
      RAISE WARNING '%',
        jsonb_build_object(
          'code', 'ATTRIBUTION_REQUIRED',
          'class', 'internal',
          'context', context
        );
    END IF;
  ELSIF entity_id IS NOT NULL AND entity_type IS NULL THEN
    context := jsonb_build_object(
      'argument', 'entity_type',
      'claim', 'jwt.claims.entity_type',
      'entity_id', entity_id
    );
    IF strict_attribution THEN
      PERFORM errors.raise_error('ENTITY_TYPE_REQUIRED', context, 'internal');
    ELSE
      RAISE WARNING '%',
        jsonb_build_object(
          'code', 'ENTITY_TYPE_REQUIRED',
          'class', 'internal',
          'context', context
        );
    END IF;
  ELSIF entity_type IS NOT NULL AND entity_id IS NULL THEN
    context := jsonb_build_object(
      'argument', 'entity_id',
      'claim', 'jwt.claims.entity_id',
      'entity_type', entity_type
    );
    IF strict_attribution THEN
      PERFORM errors.raise_error('ENTITY_ID_REQUIRED', context, 'internal');
    ELSE
      RAISE WARNING '%',
        jsonb_build_object(
          'code', 'ENTITY_ID_REQUIRED',
          'class', 'internal',
          'context', context
        );
    END IF;
  END IF;
END;
$$
LANGUAGE 'plpgsql' STABLE PARALLEL SAFE;

COMMIT;
