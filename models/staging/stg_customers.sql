-- ============================================
-- stg_customers.sql
-- 고객 원천을 가볍게 정리.
-- 여기서 country_to_region 매크로를 호출 → 매크로 예시 보기 좋음
-- ============================================

SELECT
    customer_id,
    country,
    {{ country_to_region('country') }}   AS region,         -- 매크로 호출
    CAST(signup_at AS TIMESTAMP)         AS signed_up_at
FROM {{ source('raw', 'customers') }}
