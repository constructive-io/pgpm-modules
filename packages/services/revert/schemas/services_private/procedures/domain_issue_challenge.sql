-- Revert schemas/services_private/procedures/domain_issue_challenge

BEGIN;

DROP FUNCTION IF EXISTS services_private.domain_issue_challenge(uuid, text, uuid);

COMMIT;
