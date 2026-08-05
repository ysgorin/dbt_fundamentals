-- Import CTEs
with raw_orders as (
    select *
    from {{ source('jaffle_shop', 'orders') }}
),

raw_customers as (
    select *
    from {{ source('jaffle_shop', 'customers') }}
),

raw_payments as (
    select *
    from {{ source('stripe', 'payment') }}
),

-- Staging CTEs
customers as (
    select
        id as customer_id,
        first_name as givenname,
        last_name as surname,
        first_name || ' ' || last_name as full_name
    from raw_customers 
),

orders as (
    select
        id as order_id,
        user_id as customer_id,
        order_date,
        status as order_status,
        _etl_loaded_at,
        row_number() over (
            partition by user_id
            order by order_date, id
        ) as user_order_seq
    from raw_orders
),

payments as (
    select
        id as payment_id,
        orderid as order_id,
        paymentmethod as payment_method,
        status as payment_status,
        round(amount / 100.0, 2) as payment_amount,
        created as payment_created_at,
        _batched_at
    from raw_payments
),

-- Logical CTEs
customer_order_history as (
    select
        customers.customer_id,
        customers.full_name,
        customers.surname,
        customers.givenname,
        min(orders.order_date) as first_order_date,
        min(
            case
                when orders.order_status not in ('returned', 'return_pending')
                    then orders.order_date
            end
        ) as first_non_returned_order_date,
        max(
            case
                when orders.order_status not in ('returned', 'return_pending')
                    then orders.order_date
            end
        ) as most_recent_non_returned_order_date,
        coalesce(max(orders.user_order_seq), 0) as order_count,
        coalesce(count(
            case
                when orders.order_status != 'returned'
                    then 1
            end
        ), 0) as non_returned_order_count,
        sum(
            case
                when orders.order_status not in ('returned', 'return_pending')
                    then payments.payment_amount
                else 0
            end
        ) as total_lifetime_value,
        sum(
            case
                when orders.order_status not in ('returned', 'return_pending')
                    then payments.payment_amount
                else 0
            end
        ) / nullif(
            count(
                case
                    when orders.order_status not in ('returned', 'return_pending')
                        then 1
                end
            ), 0
        ) as avg_non_returned_order_value,
        array_agg(distinct orders.order_id) as order_ids
    from orders
    join customers
        on orders.customer_id = customers.customer_id
    left outer join payments
        on orders.order_id = payments.order_id

    where orders.order_status not in ('pending') and payments.payment_status != 'fail'

    group by customers.customer_id, customers.full_name, customers.surname, customers.givenname
),

-- Final CTE
final as (
    select
        orders.order_id,
        orders.customer_id,
        customers.surname,
        customers.givenname,
        customer_order_history.first_order_date,
        customer_order_history.order_count,
        customer_order_history.total_lifetime_value,
        payment_amount as order_value_dollars,
        orders.order_status,
        payments.payment_status
    from orders

    join customers
        on orders.customer_id = customers.customer_id

    join customer_order_history
        on orders.customer_id = customer_order_history.customer_id

    left outer join payments
        on orders.order_id = payments.order_id

    where payments.payment_status != 'fail'
)

select *
from final
