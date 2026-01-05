-- Deploy schemas/services_public/tables/sites/table to pg

-- requires: schemas/services_public/schema
-- requires: schemas/metaschema_public/tables/database/table 

BEGIN;

CREATE TABLE services_public.sites (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4 (),
  database_id uuid NOT NULL,
  title text,
  description text,
  og_image image,
  favicon attachment,
  apple_touch_icon image,
  logo image,
  
  -- do we need this?
  dbname text NOT NULL DEFAULT current_database(),

  --
  CONSTRAINT db_fkey FOREIGN KEY (database_id) REFERENCES metaschema_public.database (id) ON DELETE CASCADE,
  CONSTRAINT max_title CHECK ( character_length(title) <= 120 ),
  CONSTRAINT max_descr CHECK ( character_length(description) <= 120 )
);

COMMENT ON CONSTRAINT db_fkey ON services_public.sites IS E'@omit manyToMany';
CREATE INDEX sites_database_id_idx ON services_public.sites ( database_id );

COMMIT;
