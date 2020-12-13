-- Revert: schemas/rls_public/tables/claimed_invites/columns/created_at/alterations/alt0000000068 from pg

BEGIN;


ALTER TABLE "rls_public".claimed_invites 
    ALTER COLUMN created_at DROP NOT NULL;


COMMIT;  

