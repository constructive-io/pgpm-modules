-- Revert schemas/stamps/procedures/utils from pg

BEGIN;

DROP FUNCTION stamps.timestamps();
DROP FUNCTION stamps.peoplestamps();

COMMIT;
