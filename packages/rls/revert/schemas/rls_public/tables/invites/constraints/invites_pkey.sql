-- Revert: schemas/rls_public/tables/invites/constraints/invites_pkey from pg

BEGIN;


ALTER TABLE "rls_public".invites 
    DROP CONSTRAINT invites_pkey;

COMMIT;  

