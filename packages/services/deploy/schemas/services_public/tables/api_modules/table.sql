-- Deploy schemas/services_public/tables/api_modules/table to pg

-- requires: schemas/services_public/schema
-- requires: schemas/services_public/tables/apis/table 
-- requires: schemas/metaschema_public/tables/database/table 

BEGIN;

CREATE TABLE services_public.api_modules (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4 (),
    database_id uuid NOT NULL,
    api_id uuid NOT NULL,
    name text NOT NULL,
    data json NOT NULL,

    --

    CONSTRAINT db_fkey FOREIGN KEY (database_id) REFERENCES metaschema_public.database (id) ON DELETE CASCADE

);

ALTER TABLE services_public.api_modules ADD CONSTRAINT api_modules_api_id_fkey FOREIGN KEY ( api_id ) REFERENCES services_public.apis ( id );
COMMENT ON CONSTRAINT api_modules_api_id_fkey ON services_public.api_modules IS E'@omit manyToMany';
CREATE INDEX api_modules_api_id_idx ON services_public.api_modules ( api_id );

COMMENT ON CONSTRAINT db_fkey ON services_public.api_modules IS E'@omit manyToMany';
CREATE INDEX api_modules_database_id_idx ON services_public.api_modules ( database_id );


COMMIT;
