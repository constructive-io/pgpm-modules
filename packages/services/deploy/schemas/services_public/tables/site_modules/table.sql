-- Deploy schemas/services_public/tables/site_modules/table to pg

-- requires: schemas/services_public/schema
-- requires: schemas/services_public/tables/sites/table 
-- requires: schemas/metaschema_public/tables/database/table 

BEGIN;

CREATE TABLE services_public.site_modules (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4 (),
    database_id uuid NOT NULL,
    site_id uuid NOT NULL,
    name text NOT NULL,
    data json NOT NULL,

    --
    CONSTRAINT db_fkey FOREIGN KEY (database_id) REFERENCES metaschema_public.database (id) ON DELETE CASCADE
);

ALTER TABLE services_public.site_modules ADD CONSTRAINT site_modules_site_id_fkey FOREIGN KEY ( site_id ) REFERENCES services_public.sites ( id );
COMMENT ON CONSTRAINT site_modules_site_id_fkey ON services_public.site_modules IS E'@omit manyToMany';
CREATE INDEX site_modules_site_id_idx ON services_public.site_modules ( site_id );

COMMENT ON CONSTRAINT db_fkey ON services_public.site_modules IS E'@omit manyToMany';
CREATE INDEX site_modules_database_id_idx ON services_public.site_modules ( database_id );


COMMIT;
