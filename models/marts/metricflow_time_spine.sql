-- ============================================
-- metricflow_time_spine.sql
-- MetricFlow가 요구하는 "시간축" 모델 — 하루 1행씩 연속된 날짜.
-- 시간 기반 지표(일별 집계, 누적 등)의 기준이 됨.
-- dbt_utils.date_spine 으로 날짜 시리즈를 생성.
-- ============================================

{{ config(materialized='table') }}

WITH days AS (
    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('2024-01-01' as date)",
        end_date="cast('2027-01-01' as date)"
    ) }}
)

SELECT CAST(date_day AS DATE) AS date_day
FROM days
