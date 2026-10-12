-- Deploy schemas/app_jobs/procedures/schedule_next_run to pg

-- requires: schemas/app_jobs/schema
-- requires: schemas/app_jobs/procedures/cron_field_values
-- requires: errors:schemas/errors/procedures/raise_error

BEGIN;

-- Next instant strictly after `after` at which a scheduled_jobs.schedule_info
-- spec fires. Evaluated on the UTC wall clock at second resolution.
--
-- Accepts the shapes stored in schedule_info:
--   { "rule": "0 */15 * * * *" }   6-field cron: sec min hour dom month dow
--   { "rule": "*/15 * * * *" }     5-field cron: min hour dom month dow
--   { "second": 0, "minute": [0, 30], "hour": 9, "dayOfWeek": [1, 2, 3] }
--     recurrence object: each field a number, an array of numbers, or a
--     {"start", "end", "step"} range; an absent field matches every value,
--     except "second" which defaults to 0; "month" is 0-11 and
--     "dayOfWeek" 0-6, as node-schedule's RecurrenceRule defines them.
-- Day-of-month and day-of-week both restricted match when either does
-- (Vixie cron semantics).
CREATE FUNCTION app_jobs.schedule_next_run (schedule_info json, after timestamptz DEFAULT now())
  RETURNS timestamptz
  AS $$
DECLARE
  rule text;
  fields text[];
  seconds int[];
  minutes int[];
  hours int[];
  days int[];
  months int[];
  dows int[];
  dom_any boolean;
  dow_any boolean;
  day_ok boolean;
  clock timestamp;
  not_before timestamptz;
  not_after timestamptz;
  steps int := 0;
  month_names constant text[] := ARRAY['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
  dow_names constant text[] := ARRAY['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
BEGIN
  IF schedule_info IS NULL OR after IS NULL THEN
    RETURN NULL;
  END IF;

  rule := schedule_info ->> 'rule';

  IF rule IS NOT NULL THEN
    fields := regexp_split_to_array(trim(rule), '\s+');
    IF array_length(fields, 1) = 5 THEN
      fields := array_prepend('0', fields);
    ELSIF array_length(fields, 1) <> 6 THEN
      PERFORM errors.raise_error('SCHEDULE_RULE_INVALID', jsonb_build_object('rule', rule), 'public');
    END IF;
    seconds := app_jobs.cron_field_values(fields[1], 0, 59);
    minutes := app_jobs.cron_field_values(fields[2], 0, 59);
    hours := app_jobs.cron_field_values(fields[3], 0, 23);
    days := app_jobs.cron_field_values(fields[4], 1, 31);
    months := app_jobs.cron_field_values(fields[5], 1, 12, month_names);
    -- 7 is Sunday too
    dows := app_jobs.cron_field_values(fields[6], 0, 7, dow_names);
    dom_any := fields[4] IN ('*', '?');
    dow_any := fields[6] IN ('*', '?');
  ELSIF json_typeof(schedule_info) = 'object' THEN
    -- a node-schedule RecurrenceRule; every field unrestricted except second,
    -- which defaults to 0, so {} is "every minute"
    seconds := coalesce(app_jobs.recurrence_field_values(schedule_info -> 'second', 0, 59), ARRAY[0]);
    minutes := coalesce(app_jobs.recurrence_field_values(schedule_info -> 'minute', 0, 59), app_jobs.cron_field_values('*', 0, 59));
    hours := coalesce(app_jobs.recurrence_field_values(schedule_info -> 'hour', 0, 23), app_jobs.cron_field_values('*', 0, 23));
    days := coalesce(app_jobs.recurrence_field_values(schedule_info -> 'date', 1, 31), app_jobs.cron_field_values('*', 1, 31));
    months := coalesce((
      SELECT
        array_agg(m + 1 ORDER BY m)
      FROM
        unnest(app_jobs.recurrence_field_values(schedule_info -> 'month', 0, 11)) AS m), app_jobs.cron_field_values('*', 1, 12));
    dows := coalesce(app_jobs.recurrence_field_values(schedule_info -> 'dayOfWeek', 0, 6), app_jobs.cron_field_values('*', 0, 6));
    dom_any := app_jobs.recurrence_field_values(schedule_info -> 'date', 1, 31) IS NULL;
    dow_any := app_jobs.recurrence_field_values(schedule_info -> 'dayOfWeek', 0, 6) IS NULL;
  ELSE
    PERFORM errors.raise_error('SCHEDULE_RULE_INVALID', jsonb_build_object('schedule_info', schedule_info::jsonb), 'public');
  END IF;

  IF 7 = ANY (dows) THEN
    dows := ARRAY (
      SELECT DISTINCT
        CASE WHEN d = 7 THEN 0 ELSE d END
      FROM
        unnest(dows) AS d
      ORDER BY
        1);
  END IF;

  not_before := greatest(after, (schedule_info ->> 'start')::timestamptz);
  not_after := (schedule_info ->> 'end')::timestamptz;
  clock := date_trunc('second', not_before AT TIME ZONE 'UTC') + interval '1 second';

  LOOP
    steps := steps + 1;
    -- every branch below advances at least one unit; 5 years of month/day
    -- skipping plus the intra-day search is far below this bound
    IF steps > 100000 THEN
      PERFORM errors.raise_error('SCHEDULE_RULE_UNSATISFIABLE', jsonb_build_object('schedule_info', schedule_info::jsonb), 'public');
    END IF;

    IF NOT (extract(month FROM clock)::int = ANY (months)) THEN
      clock := date_trunc('month', clock) + interval '1 month';
      CONTINUE;
    END IF;

    day_ok := (dom_any AND dow_any)
      OR (NOT dom_any AND extract(day FROM clock)::int = ANY (days))
      OR (NOT dow_any AND extract(dow FROM clock)::int = ANY (dows));
    IF NOT day_ok THEN
      clock := date_trunc('day', clock) + interval '1 day';
      CONTINUE;
    END IF;

    IF NOT (extract(hour FROM clock)::int = ANY (hours)) THEN
      clock := date_trunc('hour', clock) + interval '1 hour';
      CONTINUE;
    END IF;

    IF NOT (extract(minute FROM clock)::int = ANY (minutes)) THEN
      clock := date_trunc('minute', clock) + interval '1 minute';
      CONTINUE;
    END IF;

    IF NOT (extract(second FROM clock)::int = ANY (seconds)) THEN
      clock := clock + interval '1 second';
      CONTINUE;
    END IF;

    IF not_after IS NOT NULL AND clock AT TIME ZONE 'UTC' > not_after THEN
      RETURN NULL;
    END IF;
    RETURN clock AT TIME ZONE 'UTC';
  END LOOP;
END;
$$
LANGUAGE 'plpgsql'
IMMUTABLE;

-- One node-schedule RecurrenceRule field as the set of values it matches:
-- a number, an array of numbers and/or {"start","end","step"} ranges, or a
-- single range. NULL (absent or JSON null) means unrestricted.
CREATE FUNCTION app_jobs.recurrence_field_values (value json, low int, high int)
  RETURNS int[]
  AS $$
DECLARE
  item json;
  values int[] := '{}';
  range_low int;
  range_high int;
  step int;
BEGIN
  IF value IS NULL OR json_typeof(value) = 'null' THEN
    RETURN NULL;
  END IF;

  FOR item IN
  SELECT
    *
  FROM
    json_array_elements(
      CASE WHEN json_typeof(value) = 'array' THEN
        value
      ELSE
        json_build_array(value)
      END) LOOP
    IF json_typeof(item) = 'number' THEN
      range_low := (item #>> '{}')::numeric::int;
      range_high := range_low;
      step := 1;
    ELSIF json_typeof(item) = 'object' AND item -> 'start' IS NOT NULL THEN
      range_low := (item ->> 'start')::numeric::int;
      range_high := coalesce((item ->> 'end')::numeric::int, high);
      step := coalesce((item ->> 'step')::numeric::int, 1);
    ELSE
      PERFORM errors.raise_error('SCHEDULE_RULE_INVALID', jsonb_build_object('value', value::jsonb), 'public');
    END IF;

    IF range_low < low OR range_high > high OR range_low > range_high OR step < 1 THEN
      PERFORM errors.raise_error('SCHEDULE_RULE_INVALID', jsonb_build_object('value', value::jsonb), 'public');
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

COMMIT;
