-- Deploy schemas/metaschema_public/tables/scheduled_cron/table to pg

-- requires: schemas/metaschema_public/schema
-- requires: schemas/metaschema_public/tables/database/table

BEGIN;

CREATE TABLE metaschema_public.scheduled_cron (
  id          uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  database_id uuid NOT NULL,
  name        text NOT NULL,
  schedule    text NOT NULL,
  command     text NOT NULL,
  is_enabled  boolean NOT NULL DEFAULT true,

  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),

  CONSTRAINT scheduled_cron_database_fkey
    FOREIGN KEY (database_id)
    REFERENCES metaschema_public.database (id)
    ON DELETE CASCADE,

  CONSTRAINT scheduled_cron_database_name_unique
    UNIQUE (database_id, name)
);

CREATE INDEX scheduled_cron_database_id_idx
  ON metaschema_public.scheduled_cron (database_id);

COMMIT;
