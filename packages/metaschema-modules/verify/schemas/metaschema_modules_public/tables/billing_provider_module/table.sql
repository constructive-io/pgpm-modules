-- Verify schemas/metaschema_modules_public/tables/billing_provider_module/table on pg

BEGIN;

SELECT
  id,
  database_id,
  schema_id,
  private_schema_id,
  provider,
  products_table_id,
  prices_table_id,
  subscriptions_table_id,
  billing_customers_table_id,
  billing_customers_table_name,
  billing_products_table_id,
  billing_products_table_name,
  billing_prices_table_id,
  billing_prices_table_name,
  billing_subscriptions_table_id,
  billing_subscriptions_table_name,
  billing_webhook_events_table_id,
  billing_webhook_events_table_name,
  process_billing_event_function,
  get_billing_subscription_by_entity_function,
  get_billing_subscription_by_external_id_function,
  get_plan_pricing_by_external_price_function,
  billing_operations_table_id,
  billing_operations_table_name,
  billing_provider_state_table_id,
  billing_provider_state_table_name,
  billing_health_table_id,
  billing_health_table_name,
  reserve_billing_operation_function,
  finish_billing_operation_function,
  apply_provider_observation_function,
  list_due_reconciliations_function,
  prepare_scheduled_change_function,
  clear_scheduled_change_function,
  get_billing_provider_state_function,
  record_billing_health_function,
  prefix
FROM metaschema_modules_public.billing_provider_module
WHERE FALSE;

ROLLBACK;
