{{ config(
    materialized='incremental',
    unique_key=['sold_at', 'store_id'],
    incremental_strategy='delete+insert',
    on_schema_change='append_new_columns',
    tags=['daily']
) }}

WITH sales AS (
    SELECT * FROM {{ ref('stg_store_sales') }}
    WHERE status = 'completed'

    {% if is_incremental() %}
      {% if var('start_date', none) is not none and var('end_date', none) is not none %}
        -- backfill 모드: --vars로 받은 날짜 범위만 처리 (멱등)
        -- 예) dbt run -s fct_orders_daily --vars '{"start_date":"2024-01-01","end_date":"2024-01-31"}'
        AND CAST(sold_at AS DATE) >= '{{ var("start_date") }}'
        AND CAST(sold_at AS DATE) <= '{{ var("end_date") }}'
      {% else %}
        -- 일반 모드: 최근 3일치 재처리 (늦게 도착하는 데이터 대응)
        AND sold_at > (SELECT MAX(sold_at) - INTERVAL '3 days' FROM {{ this }})
      {% endif %}
    {% endif %}
),

stores AS (
    SELECT * FROM {{ ref('stg_stores') }}
),

daily AS (
    SELECT
        CAST(a.sold_at AS DATE)  AS sold_at,   -- DuckDB엔 DATE() 함수 없음 → CAST 사용
        a.store_id,
        b.store_name,
        COUNT(*)                 AS sale_cnt,
        SUM(a.sale_amount)      AS daily_revenue
    FROM sales a
    LEFT JOIN stores b USING (store_id)
    GROUP BY 1, 2, 3
)

SELECT
    -- dbt_utils: order_date + region 을 합쳐 해시 대리키(PK) 생성.
    -- 복합키를 컬럼 하나로 다루고 싶을 때 유용 (조인/중복체크 편해짐)
    {{ dbt_utils.generate_surrogate_key(['sold_at', 'store_id']) }} AS sale_store_key,
    *
FROM daily