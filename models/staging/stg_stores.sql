
SELECT store_id
      ,store_name
      ,region
      ,city
  from {{ source('raw', 'stores') }}