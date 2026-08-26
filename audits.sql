-- Compare Row Counts
{% set old_relation = adapter.get_relation(
      database = "jaffle-shop-498502",
      schema = "jaffle_shop",
      identifier = "customer_orders_legacy"
) -%}

{% set dbt_relation = ref('fct_customer_orders') %}

{{ audit_helper.compare_row_counts(
    a_relation = old_relation,
    b_relation = dbt_relation
) }}

-- Compare All Columns

-- {% set old_relation = adapter.get_relation(
--       database = "`jaffle-shop-498502",
--       schema = "jaffle_shop",
--       identifier = "customer_orders_legacy"
-- ) -%}

-- {% set dbt_relation = ref('fct_customer_orders') %}

-- {{ audit_helper.compare_all_columns(
--     a_relation = old_relation,
--     b_relation = dbt_relation,
--     primary_key = "order_id"
-- ) }}
