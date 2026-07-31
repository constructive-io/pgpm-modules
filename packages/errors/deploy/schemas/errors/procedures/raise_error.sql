-- Deploy schemas/errors/procedures/raise_error to pg

-- requires: schemas/errors/schema

BEGIN;

-- Canonical error raiser. Every application error should funnel through this so
-- clients receive one consistent, machine-readable shape:
--   MESSAGE = code           (bare code; message-scanning clients keep working)
--   DETAIL  = { code, context, class }  (the machine-readable contract)
--   ERRCODE = P0001          (semantic code rides in DETAIL, not SQLSTATE)
-- Raw context values travel untouched (no server-side interpolation), enabling
-- i18n on dynamic errors. class is 'public' (user-facing) or 'internal' (masked).
CREATE FUNCTION errors.raise_error(
  code text,
  context jsonb DEFAULT '{}'::jsonb,
  error_class text DEFAULT 'internal'
) RETURNS void AS $$
BEGIN
  RAISE EXCEPTION USING
    ERRCODE = 'P0001',
    MESSAGE = code,
    DETAIL = jsonb_build_object(
      'code', code,
      'context', COALESCE(context, '{}'::jsonb),
      'class', error_class
    )::text;
END;
$$ LANGUAGE plpgsql;

COMMIT;
