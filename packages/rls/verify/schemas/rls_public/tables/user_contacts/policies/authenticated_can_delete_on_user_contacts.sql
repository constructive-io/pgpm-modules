-- Verify: schemas/rls_public/tables/user_contacts/policies/authenticated_can_delete_on_user_contacts on pg

BEGIN;
SELECT verify_policy('authenticated_can_delete_on_user_contacts', 'rls_public.user_contacts');
COMMIT;  

