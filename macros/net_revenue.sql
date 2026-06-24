-- ============================================
-- net_revenue (매크로)
-- "순매출" = completed 주문 금액만 합산. 여러 모델에서 재사용.
-- 로직을 여기 한 곳에서 관리 → 정의 바뀌면 쓰는 모든 모델에 일괄 반영.
-- ============================================
{% macro net_revenue(amount_column, status_column) %}
    SUM(CASE WHEN {{ status_column }} = 'completed' THEN {{ amount_column }} ELSE 0 END)
{% endmacro %}