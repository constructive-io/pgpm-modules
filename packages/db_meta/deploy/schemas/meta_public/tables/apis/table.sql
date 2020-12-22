-- Deploy schemas/meta_public/tables/apis/table to pg

-- requires: schemas/meta_public/schema
-- requires: schemas/meta_public/tables/domains/table 
-- requires: schemas/collections_public/tables/database/table 

BEGIN;

CREATE TABLE meta_public.apis (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4 (),
    database_id uuid NOT NULL REFERENCES collections_public.database (id) ON DELETE CASCADE,
    name text NOT NULL,
    domain_id uuid NOT NULL,
    dbname text NOT NULL DEFAULT current_database(),
    role_name text NOT NULL DEFAULT 'authenticated',
    anon_role text NOT NULL DEFAULT 'anonymous',
    is_public boolean NOT NULL DEFAULT true,
    UNIQUE(database_id, name),
    UNIQUE(domain_id)
);

ALTER TABLE meta_public.apis ADD CONSTRAINT apis_domain_id_fkey FOREIGN KEY ( domain_id ) REFERENCES meta_public.domains ( id );
COMMENT ON CONSTRAINT apis_domain_id_fkey ON meta_public.apis IS E'@omit manyToMany';

CREATE INDEX apis_domain_id_idx ON meta_public.apis ( domain_id );
CREATE INDEX apis_database_id_idx ON meta_public.apis ( database_id );

COMMIT;
