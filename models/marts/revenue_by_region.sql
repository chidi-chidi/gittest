-- 지역별 순매출 (net_revenue 매크로 사용)
SELECT
    c.region,
    {{ net_revenue('o.order_amount', 'o.order_status') }} AS net_revenue,
    COUNT(*) AS order_cnt
FROM {{ ref('stg_orders') }} o
LEFT JOIN {{ ref('stg_customers') }} c USING (customer_id)
GROUP BY 1