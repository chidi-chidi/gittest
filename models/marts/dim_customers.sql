-- ============================================
-- dim_customers.sql
-- 고객 디멘전 테이블. fact 테이블과 join해서 분석에 사용.
-- 비교적 작아서 매번 전체 재생성 (table)
-- ============================================

{{ config(
    materialized='table',
    tags=['daily']
) }}

WITH customers AS (
    SELECT * FROM {{ ref('stg_customers') }}
),

order_stats AS (
    SELECT
        customer_id,
        COUNT(*)             AS lifetime_orders,
        SUM(order_amount)    AS lifetime_value,
        MIN(ordered_at)      AS first_ordered_at,
        MAX(ordered_at)      AS last_ordered_at
    FROM {{ ref('stg_orders') }}
    WHERE order_status = 'completed'
    GROUP BY 1
)

SELECT
    c.customer_id,
    c.country,
    c.region,
    c.signed_up_at,
    COALESCE(o.lifetime_orders, 0)   AS lifetime_orders,
    COALESCE(o.lifetime_value, 0)    AS lifetime_value,
    o.first_ordered_at,
    o.last_ordered_at,

    -- 세그멘테이션
    CASE
        WHEN o.lifetime_value IS NULL    THEN 'inactive'
        WHEN o.lifetime_value >= 1000000 THEN 'vip'
        WHEN o.lifetime_value >= 100000  THEN 'regular'
        ELSE 'casual'
    END AS customer_segment
FROM customers c
LEFT JOIN order_stats o USING (customer_id)
