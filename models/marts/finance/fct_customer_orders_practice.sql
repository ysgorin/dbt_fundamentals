-- Import CTEs
with RAW_ORDERS as (
    select *
    from {{ source('jaffle_shop', 'orders') }}
),

RAW_CUSTOMERS as (
    select *
    from {{ source('jaffle_shop', 'customers') }}
),

RAW_PAYMENTS as (
    select *
    from {{ source('stripe', 'payment') }}
),

P as (
    select
        ORDERID as ORDER_ID,
        max(CREATED) as PAYMENT_FINALIZED_DATE,
        sum(AMOUNT) / 100.0 as TOTAL_AMOUND_PAID
    from RAW_PAYMENTS
    where STATUS <> 'fail'
    group by ORDERID
),

PAID_ORDERS as (
    select
        ORDERS.ID as ORDER_ID,
        ORDERS.USER_ID as CUSTOMER_ID,
        ORDERS.ORDER_DATE as ORDER_PLACED_AT,
        ORDERS.STATUS as ORDER_STATUS,
        P.TOTAL_AMOUND_PAID,
        P.PAYMENT_FINALIZED_DATE,
        C.FIRST_NAME as CUSTOMER_FIRST_NAME,
        C.LAST_NAME as CUSTOMER_LAST_NAME
    from RAW_ORDERS as ORDERS
    left join P
        on ORDERS.ID = P.ORDER_ID
    left join RAW_CUSTOMERS as C
        on ORDERS.USER_ID = C.ID
),

CUSTOMER_ORDERS as (
    select
        C.ID as CUSTOMER_ID,
        min(ORDERS.ORDER_DATE) as FIRST_ORDER_DATE,
        max(ORDERS.ORDER_DATE) as MOST_RECENT_ORDER_DATE,
        count(ORDERS.ID) as NUMBER_OF_ORDERS
    from RAW_CUSTOMERS as C
    left join RAW_ORDERS as ORDERS
        on C.ID = ORDERS.USER_ID
    group by C.ID
),

X as (
    select
        ORDER_ID,
        sum(TOTAL_AMOUND_PAID) over (
            partition by CUSTOMER_ID
            order by ORDER_ID
        ) as CLV
    from PAID_ORDERS
    order by ORDER_ID
),

FINAL as (
    select
        P.*,
        row_number() over (order by P.ORDER_ID) as TRANSACTION_SEQ,
        row_number() over (
            partition by P.CUSTOMER_ID
            order by P.ORDER_ID
        ) as CUSTOMER_SALES_SEQ,
        case
            when C.FIRST_ORDER_DATE = P.ORDER_PLACED_AT
                then 'new'
            else 'return'
        end as NVSR,
        X.CLV as CUSTOMER_LIFETIME_VALUE,
        C.FIRST_ORDER_DATE as FDOS
    from PAID_ORDERS as P
    left join CUSTOMER_ORDERS as C
        on P.CUSTOMER_ID = C.CUSTOMER_ID
    left outer join X
        on P.ORDER_ID = X.ORDER_ID
    order by P.ORDER_ID
)

select *
from FINAL;
