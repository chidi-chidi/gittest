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
    on_schema_change='append_new_columns',
    tags=['daily', 'finance']
) }}

WITH orders AS (
    SELECT * FROM {{ ref('stg_orders') }}
    WHERE order_status = 'completed'

    {% if is_incremental() %}
      -- 2번째 실행부터: 이미 처리한 날짜 이후만 가져옴
      -- {{ this }} = 현재 모델 자신 (fct_orders_daily)
      -- 3일치 안전마진을 둠 (늦게 도착하는 데이터 대응)
      AND ordered_at > (SELECT MAX(order_date) - INTERVAL '3 days' FROM {{ this }})
    {% endif %}
),

customers AS (
    SELECT * FROM {{ ref('stg_customers') }}
)

SELECT
    CAST(o.ordered_at AS DATE)  AS order_date,   -- DuckDB엔 DATE() 함수 없음 → CAST 사용
    c.region,
    COUNT(*)                 AS order_cnt,
    SUM(o.order_amount)      AS revenue,
    AVG(o.order_amount)      AS avg_order_value
FROM orders o
LEFT JOIN customers c USING (customer_id)
GROUP BY 1, 2
