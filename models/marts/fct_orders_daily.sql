-- ============================================
-- fct_orders_daily.sql
-- "mart" 레이어: 분석가/BI가 직접 쓰는 비즈니스 마트.
-- 일자 + 지역별 매출 집계 fact 테이블.
--
-- 이 모델은 incremental → 매일 새 데이터만 추가 (대용량 가정)
-- ============================================

{{ config(
    materialized='incremental',
    unique_key=['order_date', 'region'],
    incremental_strategy='delete+insert',
    on_schema_change='append_new_columns',
    tags=['daily', 'finance']
) }}

WITH orders AS (
    SELECT * FROM {{ ref('stg_orders') }}
    WHERE order_status = 'completed'

    {% if is_incremental() %}
      {% if var('start_date', none) is not none and var('end_date', none) is not none %}
        -- backfill 모드: --vars로 받은 날짜 범위만 처리 (멱등)
        -- 예) dbt run -s fct_orders_daily --vars '{"start_date":"2024-01-01","end_date":"2024-01-31"}'
        AND CAST(ordered_at AS DATE) >= '{{ var("start_date") }}'
        AND CAST(ordered_at AS DATE) <= '{{ var("end_date") }}'
      {% else %}
        -- 일반 모드: 최근 3일치 재처리 (늦게 도착하는 데이터 대응)
        AND ordered_at > (SELECT MAX(order_date) - INTERVAL '3 days' FROM {{ this }})
      {% endif %}
    {% endif %}
),

customers AS (
    SELECT * FROM {{ ref('stg_customers') }}
),

daily AS (
    SELECT
        CAST(o.ordered_at AS DATE)  AS order_date,   -- DuckDB엔 DATE() 함수 없음 → CAST 사용
        c.region,
        COUNT(*)                 AS order_cnt,
        SUM(o.order_amount)      AS revenue,
        AVG(o.order_amount)      AS avg_order_value
    FROM orders o
    LEFT JOIN customers c USING (customer_id)
    GROUP BY 1, 2
)

SELECT
    -- dbt_utils: order_date + region 을 합쳐 해시 대리키(PK) 생성.
    -- 복합키를 컬럼 하나로 다루고 싶을 때 유용 (조인/중복체크 편해짐)
    {{ dbt_utils.generate_surrogate_key(['order_date', 'region']) }} AS order_region_key,
    *
FROM daily
