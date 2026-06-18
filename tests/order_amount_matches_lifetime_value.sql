-- ============================================
-- Singular test 예시 #2
-- "dim_customers의 lifetime_value는 stg_orders의 고객별 합계와 일치해야 한다"
--
-- 이런 "두 모델 간 정합성 체크"는 not_null/unique 같은 단순 테스트로는
-- 표현할 수 없어서 singular test로 작성.
-- ============================================

WITH source_total AS (
    SELECT
        customer_id,
        SUM(order_amount) AS total_from_orders
    FROM {{ ref('stg_orders') }}
    WHERE order_status = 'completed'
    GROUP BY 1
),

mart_total AS (
    SELECT
        customer_id,
        lifetime_value
    FROM {{ ref('dim_customers') }}
)

SELECT
    m.customer_id,
    m.lifetime_value           AS in_mart,
    s.total_from_orders        AS in_source
FROM mart_total m
JOIN source_total s USING (customer_id)
WHERE m.lifetime_value != s.total_from_orders
