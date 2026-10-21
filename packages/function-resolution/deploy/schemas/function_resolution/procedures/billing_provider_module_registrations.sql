-- Deploy schemas/function_resolution/procedures/billing_provider_module_registrations to pg

-- requires: schemas/function_resolution/schema
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/billing_module/table
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/billing_provider_module/table
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/limits_module/table
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/plans_module/table
-- requires: metaschema-modules:schemas/metaschema_modules_public/tables/user_auth_module/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/schema/table
-- requires: metaschema-schema:schemas/metaschema_public/tables/table/table
-- requires: pgpm-app-scope:schemas/app_scope/procedures/platform_database_id

BEGIN;

-- billing_provider_module_registrations: the billing_provider_module rows the platform login reads (module loader,
-- worker and reconciler). A NOBYPASSRLS login sees none of these rows directly, so
-- this SECURITY DEFINER reader is its only way in: keyed by owner_database_id
-- (the module has no surface lookup). Projection only — no secret column is
-- returned. Granted to the platform login alone (fun platform COMPONENT_GRANTS);
-- not exposed through GraphQL.
CREATE FUNCTION function_resolution.billing_provider_module_registrations(owner_database_id uuid)
RETURNS TABLE (
    database_id uuid,
    platform_owned boolean,
    scope text,
    provider text,
    private_schema text,
    list_pending_usage_sync_function text,
    mark_usage_synced_function text,
    get_billing_customer_function text,
    upsert_billing_customer_function text,
    get_billing_product_function text,
    upsert_billing_product_function text,
    get_billing_price_function text,
    upsert_billing_price_function text,
    get_billing_subscription_function text,
    upsert_billing_subscription_function text,
    sweep_overdue_subscriptions_function text,
    get_active_plan_pricing_function text,
    get_fallback_free_plan_function text,
    activate_plan_subscription_function text,
    get_active_plan_subscription_function text,
    get_billing_subscription_by_entity_function text,
    get_billing_subscription_by_external_id_function text,
    get_plan_pricing_by_external_price_function text,
    reserve_billing_operation_function text,
    finish_billing_operation_function text,
    apply_provider_observation_function text,
    list_due_reconciliations_function text,
    prepare_scheduled_change_function text,
    clear_scheduled_change_function text,
    get_billing_provider_state_function text,
    record_billing_health_function text,
    record_billing_connection_function text,
    billing_provider_key_function text,
    bind_checkout_session_function text,
    upsert_invoice_function text,
    record_refund_function text,
    record_dispute_function text,
    billing_customers_table_name text,
    billing_prices_table_name text,
    billing_subscriptions_table_name text,
    customers_schema text,
    customers_table text,
    subscriptions_schema text,
    subscriptions_table text,
    products_schema text,
    products_table text,
    prices_schema text,
    prices_table text,
    invoices_schema text,
    invoices_table text,
    operations_schema text,
    operations_table text,
    provider_state_schema text,
    provider_state_table text,
    health_schema text,
    health_table text,
    meters_schema text,
    meters_table text,
    credit_packs_schema text,
    credit_packs_table text,
    plan_subscriptions_schema text,
    plan_subscriptions_table text,
    ledger_schema text,
    ledger_table text,
    balances_schema text,
    balances_table text,
    meter_credits_schema text,
    meter_credits_table text,
    plans_schema text,
    plans_table text,
    plan_pricing_schema text,
    plan_pricing_table text,
    plan_limits_schema text,
    plan_limits_table text,
    plan_meter_limits_schema text,
    plan_meter_limits_table text,
    plan_caps_schema text,
    plan_caps_table text,
    limits_schema text,
    limits_table text,
    limit_defaults_schema text,
    limit_defaults_table text,
    users_schema text,
    users_table text
) AS $$
SELECT
    bpm.database_id,
    (bpm.database_id = app_scope.platform_database_id()) AS platform_owned,
    'app'::text AS scope,
    bpm.provider,
    pvs.schema_name AS private_schema,
    bpm.list_pending_usage_sync_function,
    bpm.mark_usage_synced_function,
    bpm.get_billing_customer_function,
    bpm.upsert_billing_customer_function,
    bpm.get_billing_product_function,
    bpm.upsert_billing_product_function,
    bpm.get_billing_price_function,
    bpm.upsert_billing_price_function,
    bpm.get_billing_subscription_function,
    bpm.upsert_billing_subscription_function,
    bpm.sweep_overdue_subscriptions_function,
    bpm.get_active_plan_pricing_function,
    bpm.get_fallback_free_plan_function,
    bpm.activate_plan_subscription_function,
    bpm.get_active_plan_subscription_function,
    bpm.get_billing_subscription_by_entity_function,
    bpm.get_billing_subscription_by_external_id_function,
    bpm.get_plan_pricing_by_external_price_function,
    bpm.reserve_billing_operation_function,
    bpm.finish_billing_operation_function,
    bpm.apply_provider_observation_function,
    bpm.list_due_reconciliations_function,
    bpm.prepare_scheduled_change_function,
    bpm.clear_scheduled_change_function,
    bpm.get_billing_provider_state_function,
    bpm.record_billing_health_function,
    bpm.record_billing_connection_function,
    bpm.billing_provider_key_function,
    bpm.bind_checkout_session_function,
    bpm.upsert_invoice_function,
    bpm.record_refund_function,
    bpm.record_dispute_function,
    bpm.billing_customers_table_name,
    bpm.billing_prices_table_name,
    bpm.billing_subscriptions_table_name,
    s_customers.schema_name AS customers_schema,
    t_customers.name AS customers_table,
    s_subscriptions.schema_name AS subscriptions_schema,
    t_subscriptions.name AS subscriptions_table,
    s_products.schema_name AS products_schema,
    t_products.name AS products_table,
    s_prices.schema_name AS prices_schema,
    t_prices.name AS prices_table,
    s_invoices.schema_name AS invoices_schema,
    t_invoices.name AS invoices_table,
    s_operations.schema_name AS operations_schema,
    t_operations.name AS operations_table,
    s_providerState.schema_name AS provider_state_schema,
    t_providerState.name AS provider_state_table,
    s_health.schema_name AS health_schema,
    t_health.name AS health_table,
    s_meters.schema_name AS meters_schema,
    t_meters.name AS meters_table,
    s_creditPacks.schema_name AS credit_packs_schema,
    t_creditPacks.name AS credit_packs_table,
    s_planSubscriptions.schema_name AS plan_subscriptions_schema,
    t_planSubscriptions.name AS plan_subscriptions_table,
    s_ledger.schema_name AS ledger_schema,
    t_ledger.name AS ledger_table,
    s_balances.schema_name AS balances_schema,
    t_balances.name AS balances_table,
    s_meterCredits.schema_name AS meter_credits_schema,
    t_meterCredits.name AS meter_credits_table,
    s_plans.schema_name AS plans_schema,
    t_plans.name AS plans_table,
    s_planPricing.schema_name AS plan_pricing_schema,
    t_planPricing.name AS plan_pricing_table,
    s_planLimits.schema_name AS plan_limits_schema,
    t_planLimits.name AS plan_limits_table,
    s_planMeterLimits.schema_name AS plan_meter_limits_schema,
    t_planMeterLimits.name AS plan_meter_limits_table,
    s_planCaps.schema_name AS plan_caps_schema,
    t_planCaps.name AS plan_caps_table,
    s_limits.schema_name AS limits_schema,
    t_limits.name AS limits_table,
    s_limitDefaults.schema_name AS limit_defaults_schema,
    t_limitDefaults.name AS limit_defaults_table,
    s_users.schema_name AS users_schema,
    t_users.name AS users_table
FROM metaschema_modules_public.billing_provider_module AS bpm
    LEFT JOIN metaschema_public.schema pvs ON pvs.id = bpm.private_schema_id
    LEFT JOIN metaschema_modules_public.billing_module bm ON bm.database_id = bpm.database_id
    LEFT JOIN metaschema_modules_public.plans_module pm ON pm.database_id = bpm.database_id
    LEFT JOIN metaschema_modules_public.limits_module lm
    ON lm.database_id = bpm.database_id AND lm.scope = 'app'
    LEFT JOIN metaschema_modules_public.user_auth_module uam ON uam.database_id = bpm.database_id
    LEFT JOIN metaschema_public."table" t_customers ON t_customers.id = bpm.billing_customers_table_id
    LEFT JOIN metaschema_public.schema s_customers ON s_customers.id = t_customers.schema_id
    LEFT JOIN metaschema_public."table" t_subscriptions ON t_subscriptions.id = bpm.billing_subscriptions_table_id
    LEFT JOIN metaschema_public.schema s_subscriptions ON s_subscriptions.id = t_subscriptions.schema_id
    LEFT JOIN metaschema_public."table" t_products ON t_products.id = bpm.billing_products_table_id
    LEFT JOIN metaschema_public.schema s_products ON s_products.id = t_products.schema_id
    LEFT JOIN metaschema_public."table" t_prices ON t_prices.id = bpm.billing_prices_table_id
    LEFT JOIN metaschema_public.schema s_prices ON s_prices.id = t_prices.schema_id
    LEFT JOIN metaschema_public."table" t_invoices ON t_invoices.id = bpm.billing_invoices_table_id
    LEFT JOIN metaschema_public.schema s_invoices ON s_invoices.id = t_invoices.schema_id
    LEFT JOIN metaschema_public."table" t_operations ON t_operations.id = bpm.billing_operations_table_id
    LEFT JOIN metaschema_public.schema s_operations ON s_operations.id = t_operations.schema_id
    LEFT JOIN metaschema_public."table" t_providerState ON t_providerState.id = bpm.billing_provider_state_table_id
    LEFT JOIN metaschema_public.schema s_providerState ON s_providerState.id = t_providerState.schema_id
    LEFT JOIN metaschema_public."table" t_health ON t_health.id = bpm.billing_health_table_id
    LEFT JOIN metaschema_public.schema s_health ON s_health.id = t_health.schema_id
    LEFT JOIN metaschema_public."table" t_meters ON t_meters.id = bm.meters_table_id
    LEFT JOIN metaschema_public.schema s_meters ON s_meters.id = t_meters.schema_id
    LEFT JOIN metaschema_public."table" t_creditPacks ON t_creditPacks.id = bm.credit_packs_table_id
    LEFT JOIN metaschema_public.schema s_creditPacks ON s_creditPacks.id = t_creditPacks.schema_id
    LEFT JOIN metaschema_public."table" t_planSubscriptions ON t_planSubscriptions.id = bm.plan_subscriptions_table_id
    LEFT JOIN metaschema_public.schema s_planSubscriptions ON s_planSubscriptions.id = t_planSubscriptions.schema_id
    LEFT JOIN metaschema_public."table" t_ledger ON t_ledger.id = bm.ledger_table_id
    LEFT JOIN metaschema_public.schema s_ledger ON s_ledger.id = t_ledger.schema_id
    LEFT JOIN metaschema_public."table" t_balances ON t_balances.id = bm.balances_table_id
    LEFT JOIN metaschema_public.schema s_balances ON s_balances.id = t_balances.schema_id
    LEFT JOIN metaschema_public."table" t_meterCredits ON t_meterCredits.id = bm.meter_credits_table_id
    LEFT JOIN metaschema_public.schema s_meterCredits ON s_meterCredits.id = t_meterCredits.schema_id
    LEFT JOIN metaschema_public."table" t_plans ON t_plans.id = pm.plans_table_id
    LEFT JOIN metaschema_public.schema s_plans ON s_plans.id = t_plans.schema_id
    LEFT JOIN metaschema_public."table" t_planPricing ON t_planPricing.id = pm.plan_pricing_table_id
    LEFT JOIN metaschema_public.schema s_planPricing ON s_planPricing.id = t_planPricing.schema_id
    LEFT JOIN metaschema_public."table" t_planLimits ON t_planLimits.id = pm.plan_limits_table_id
    LEFT JOIN metaschema_public.schema s_planLimits ON s_planLimits.id = t_planLimits.schema_id
    LEFT JOIN metaschema_public."table" t_planMeterLimits ON t_planMeterLimits.id = pm.plan_meter_limits_table_id
    LEFT JOIN metaschema_public.schema s_planMeterLimits ON s_planMeterLimits.id = t_planMeterLimits.schema_id
    LEFT JOIN metaschema_public."table" t_planCaps ON t_planCaps.id = pm.plan_caps_table_id
    LEFT JOIN metaschema_public.schema s_planCaps ON s_planCaps.id = t_planCaps.schema_id
    LEFT JOIN metaschema_public."table" t_limits ON t_limits.id = lm.table_id
    LEFT JOIN metaschema_public.schema s_limits ON s_limits.id = t_limits.schema_id
    LEFT JOIN metaschema_public."table" t_limitDefaults ON t_limitDefaults.id = lm.default_table_id
    LEFT JOIN metaschema_public.schema s_limitDefaults ON s_limitDefaults.id = t_limitDefaults.schema_id
    LEFT JOIN metaschema_public."table" t_users ON t_users.id = uam.users_table_id
    LEFT JOIN metaschema_public.schema s_users ON s_users.id = t_users.schema_id
WHERE bpm.database_id = $1
$$ LANGUAGE sql STABLE SECURITY DEFINER;

REVOKE ALL ON FUNCTION function_resolution.billing_provider_module_registrations(uuid) FROM PUBLIC;

COMMIT;
