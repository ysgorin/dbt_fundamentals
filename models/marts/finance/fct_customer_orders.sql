-- Import CTEs
with customer_orders as (
    select *
    from {{ ref('int_customer_orders') }}
),

-- Final CTE
final as (
    select
        order_id,
        customer_id,
        surname,
        givenname,
        customer_first_order_date,
        customer_order_count,
        customer_total_lifetime_value,
        order_value_dollars,
        order_status,
        payment_status
    from customer_orders
)

select *
from final
