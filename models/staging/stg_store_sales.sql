


SELECT store_id
      ,sale_id
      ,cast(sale_date as timestamp) as sold_at
      ,lower(status) as status
      ,cast(amount as NUMERIC(18,2)) as sale_amount
  from {{ source('raw', 'store_sales') }}
 where 1=1
   and sale_date >= '{{ var("start_date") }}'