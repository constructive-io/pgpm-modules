-- Deploy roles/anon to pg

BEGIN;

DO $$
BEGIN
  IF current_setting('server_version_num')::integer >= 160000 THEN
    GRANT anonymous TO anon WITH INHERIT FALSE, SET TRUE;
  ELSE
    GRANT anonymous TO anon;
  END IF;
END;
$$;

COMMIT;
