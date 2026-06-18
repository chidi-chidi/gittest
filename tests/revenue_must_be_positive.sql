-- ============================================
-- Singular test 예시 #1
-- "fct_orders_daily의 revenue는 음수가 되면 안 된다"
--
-- 규칙: SELECT 결과가 0건이면 PASS, 1건 이상이면 FAIL
-- 실행: dbt test (자동으로 이 파일 발견함)
-- ============================================

SELECT
    order_date,
    region,
    revenue
FROM {{ ref('fct_orders_daily') }}
WHERE revenue < 0
