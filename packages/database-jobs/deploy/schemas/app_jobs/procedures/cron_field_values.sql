-- Deploy schemas/app_jobs/procedures/cron_field_values to pg

-- requires: schemas/app_jobs/schema
-- requires: errors:schemas/errors/procedures/raise_error

BEGIN;

-- Expands one cron field ("*", "?", "5", "1-5", "*/15", "1-30/5", "MON,WED",
-- "JAN-MAR") into the sorted set of integer values it matches, bounded by
-- [low, high]. names (optional) maps 3-letter tokens onto low, low+1, ...
-- Anything outside that grammar (L, W, #) is rejected.
CREATE FUNCTION app_jobs.cron_field_values (field text, low int, high int, names text[] DEFAULT NULL)
  RETURNS int[]
  AS $$
DECLARE
  part text;
  base text;
  step int;
  range_low int;
  range_high int;
  bounds text[];
  values int[] := '{}';
BEGIN
  IF field IS NULL OR field = '' THEN
    PERFORM errors.raise_error('SCHEDULE_RULE_INVALID', jsonb_build_object('field', field), 'public');
  END IF;

  FOREACH part IN ARRAY string_to_array(field, ',') LOOP
    step := 1;
    base := part;
    IF position('/' IN part) > 0 THEN
      base := split_part(part, '/', 1);
      IF split_part(part, '/', 2) !~ '^\d+$' OR split_part(part, '/', 2)::int < 1 THEN
        PERFORM errors.raise_error('SCHEDULE_RULE_INVALID', jsonb_build_object('field', field), 'public');
      END IF;
      step := split_part(part, '/', 2)::int;
    END IF;

    IF base IN ('*', '?') THEN
      range_low := low;
      range_high := high;
    ELSE
      bounds := string_to_array(base, '-');
      IF array_length(bounds, 1) > 2 THEN
        PERFORM errors.raise_error('SCHEDULE_RULE_INVALID', jsonb_build_object('field', field), 'public');
      END IF;
      range_low := app_jobs.cron_field_token(bounds[1], low, names);
      IF array_length(bounds, 1) = 2 THEN
        range_high := app_jobs.cron_field_token(bounds[2], low, names);
      ELSIF position('/' IN part) > 0 THEN
        -- "5/15" means every 15 starting at 5
        range_high := high;
      ELSE
        range_high := range_low;
      END IF;
    END IF;

    IF range_low IS NULL OR range_high IS NULL OR range_low < low OR range_high > high OR range_low > range_high THEN
      PERFORM errors.raise_error('SCHEDULE_RULE_INVALID', jsonb_build_object('field', field), 'public');
    END IF;

    values := values || ARRAY (
      SELECT
        generate_series(range_low, range_high, step));
  END LOOP;

  RETURN ARRAY (
    SELECT DISTINCT
      v
    FROM
      unnest(values) AS v
    ORDER BY
      v);
END;
$$
LANGUAGE 'plpgsql'
IMMUTABLE;

-- One token of a cron field: a non-negative integer, or a 3-letter name that
-- maps onto low + its position in names.
CREATE FUNCTION app_jobs.cron_field_token (token text, low int, names text[])
  RETURNS int
  AS $$
DECLARE
  idx int;
BEGIN
  IF token ~ '^\d+$' THEN
    RETURN token::int;
  END IF;
  IF names IS NOT NULL THEN
    idx := array_position(names, upper(token));
    IF idx IS NOT NULL THEN
      RETURN low + idx - 1;
    END IF;
  END IF;
  RETURN NULL;
END;
$$
LANGUAGE 'plpgsql'
IMMUTABLE;

COMMIT;
