-- Deploy schemas/infra_utils/procedures/param_quantity to pg

-- requires: schemas/infra_utils/schema

BEGIN;

-- Kubernetes quantity support for declared resource parameters.
--
-- A `quantity` parameter is the Kubernetes resource notation used throughout
-- workload specs — `4Gi`, `512Mi`, `500m`, `2`. It is neither free text (a typo
-- like `4GB` must fail loudly at declaration time, not silently at the API
-- server) nor a plain number (the suffix carries meaning), so it gets its own
-- declared type with a canonical numeric projection used for min/max checks.
--
-- Returns NULL when the text is not a valid quantity, so callers can test
-- validity and compare magnitudes with one call.
CREATE FUNCTION infra_utils.quantity_to_numeric(quantity text) RETURNS numeric AS $$
DECLARE
  trimmed text;
  digits text;
  suffix text;
  amount numeric;
BEGIN
  IF quantity IS NULL THEN
    RETURN NULL;
  END IF;

  trimmed := btrim(quantity);
  IF trimmed = '' THEN
    RETURN NULL;
  END IF;

  digits := substring(trimmed FROM '^[0-9]+(?:\.[0-9]+)?');
  IF digits IS NULL THEN
    RETURN NULL;
  END IF;

  suffix := substring(trimmed FROM char_length(digits) + 1);
  amount := digits::numeric;

  RETURN CASE suffix
    WHEN ''    THEN amount
    WHEN 'm'   THEN amount / 1000                      -- milli (CPU)
    WHEN 'k'   THEN amount * 1000
    WHEN 'M'   THEN amount * 1000 ^ 2
    WHEN 'G'   THEN amount * 1000 ^ 3
    WHEN 'T'   THEN amount * 1000 ^ 4
    WHEN 'Ki'  THEN amount * 1024
    WHEN 'Mi'  THEN amount * 1024 ^ 2
    WHEN 'Gi'  THEN amount * 1024 ^ 3
    WHEN 'Ti'  THEN amount * 1024 ^ 4
    ELSE NULL
  END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMIT;
