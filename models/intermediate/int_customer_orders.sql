with orders as (
    select *
    from {{ ref('int_orders') }}
),

customers as (
    select *
    from {{ ref('stg_jaffle_shop__customers') }}
),

customer_orders as (
    select
        orders.*,
        customers.full_name,
        customers.surname,
        customers.givenname,

        min(orders.order_date) over (
            partition by orders.customer_id
        ) as customer_first_order_date,

        min(orders.valid_order_date) over (
            partition by orders.customer_id
        ) as customer_first_non_returned_order_date,

        max(orders.valid_order_date) over (
            partition by orders.customer_id
        ) as customer_most_recent_non_returned_order_date,

        count(*) over (
            partition by orders.customer_id
        ) as customer_order_count,

        -- In Snowflake, not available in bigquery
        -- count(nvl2(orders.valid_order_date, 1, 0)) over (
        --     partition by orders.customer_id
        -- ) as non_returned_order_count,
        
        count(
            case
                when orders.valid_order_date is not null
                    then 1
            end) over (
            partition by orders.customer_id
        ) as customer_non_returned_order_count,

        sum(
            case
                when orders.valid_order_date is not null
                    then orders.order_value_dollars
                else 0
            end) over (
            partition by orders.customer_id
        ) as customer_total_lifetime_value,

        array_agg(orders.order_id) over (
            partition by orders.customer_id
        ) as customer_order_ids
    from orders
    inner join customers
        on orders.customer_id = customers.customer_id
),

average_customer_order_totals as (
    select
        *,
        customer_total_lifetime_value / customer_non_returned_order_count
            as customer_avg_non_returned_order_value
    from customer_orders
)

select *
from average_customer_order_totals
