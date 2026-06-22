-- ============================================
-- orders_public.sql
-- dbt_utils.star 데모.
-- stg_orders의 모든 컬럼에서 order_amount(금액)만 빼고 전부 SELECT.
-- "금액 같은 민감 컬럼을 제외한 공개용 주문 테이블" 같은 상황.
--
-- star는 컴파일 시 stg_orders 컬럼을 조회해 자동으로 나열함
-- → 원천에 컬럼이 추가돼도 (order_amount만 빼고) 자동 반영
-- ============================================

SELECT
    {{ dbt_utils.star(from=ref('stg_orders'), except=['order_amount']) }}
FROM {{ ref('stg_orders') }}
