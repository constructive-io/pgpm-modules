-- Verify: schemas/rls_public/tables/emails/policies/authenticated_can_delete_on_emails on pg

BEGIN;
SELECT verify_policy('authenticated_can_delete_on_emails', 'rls_public.emails');
COMMIT;  

