-- Revert schemas/function_resolution/procedures/owned_databases from pg

BEGIN;

DROP FUNCTION function_resolution.owned_databases(
    owner_ids uuid[]
);

COMMIT;
