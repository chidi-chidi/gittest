-- ============================================
-- stg_orders.sql
-- "staging" 레이어: 원천 테이블을 가볍게 정리.
--   - 컬럼명 표준화 (snake_case, prefix 통일)
--   - 타입 캐스팅
--   - 명백한 잘못된 값만 필터링
-- 비즈니스 로직은 여기서 거의 안 넣음 → mart 레이어에서 처리
--
-- dbt_project.yml에서 staging은 materialized=view로 설정돼 있음
-- → 매번 SELECT만 다시 실행되는 가벼운 뷰가 됨
-- ============================================

SELECT
    order_id,
    customer_id,
    CAST(order_at AS TIMESTAMP)     AS ordered_at,    -- 명칭 통일
    LOWER(status)                    AS order_status,
    CAST(amount AS NUMERIC(18, 2))   AS order_amount
FROM {{ source('raw', 'orders') }}
WHERE order_at >= '{{ var("start_date") }}'   -- dbt_project.yml의 변수 사용
