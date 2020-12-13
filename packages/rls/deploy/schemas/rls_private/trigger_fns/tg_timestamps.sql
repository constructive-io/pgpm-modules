-- Deploy: schemas/rls_private/trigger_fns/tg_timestamps to pg
-- made with <3 @ launchql.com

-- requires: schemas/rls_private/schema

BEGIN;

CREATE FUNCTION "rls_private".tg_timestamps()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
      NEW.created_at = NOW();
      NEW.updated_at = NOW();
    ELSIF TG_OP = 'UPDATE' THEN
      NEW.created_at = OLD.created_at;
      NEW.updated_at = NOW();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE 'plpgsql';
COMMIT;
