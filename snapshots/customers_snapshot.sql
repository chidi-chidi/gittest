-- ============================================
-- customers_snapshot
-- 원천 customers의 변경 이력을 SCD Type 2로 추적.
-- country가 바뀌면 → 옛 행을 닫고(dbt_valid_to 채움) 새 행을 추가.
--
-- 실행: dbt snapshot
-- 전략(strategy):
--   - timestamp : updated_at 컬럼으로 변경 감지 (원천에 적재시각 있을 때)
--   - check     : 지정한 컬럼 값이 바뀌었는지 비교 (우리 seed엔 updated_at 없어서 이걸 씀)
-- ============================================

{% snapshot customers_snapshot %}

{{
    config(
      target_schema='snapshots',
      unique_key='customer_id',
      strategy='check',
      check_cols=['country'],
    )
}}

SELECT * FROM {{ source('raw', 'customers') }}

{% endsnapshot %}
