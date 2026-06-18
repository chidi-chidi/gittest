-- ============================================
-- country_to_region.sql (매크로)
-- 옛날에 DE분이 case when을 jinja로 정리해줬다 → 이게 그 정체.
-- 매크로 = 재사용 가능한 SQL 조각.
-- 여러 모델에서 똑같은 매핑 로직 쓰지 않고, 여기 한 곳만 수정하면 됨.
-- ============================================

{% macro country_to_region(country_col) %}
    CASE
        {% set regions = {
            'APAC': ['KR', 'JP', 'CN', 'TW', 'HK', 'SG'],
            'NA':   ['US', 'CA', 'MX'],
            'EU':   ['GB', 'FR', 'DE', 'IT', 'ES', 'NL']
        } %}
        {% for region, countries in regions.items() %}
        WHEN {{ country_col }} IN ({{ "'" ~ countries|join("','") ~ "'" }}) THEN '{{ region }}'
        {% endfor %}
        ELSE 'OTHER'
    END
{% endmacro %}

-- 사용법:
--   SELECT {{ country_to_region('country') }} AS region FROM ...
--
-- dbt가 컴파일하면 실제로는 이런 SQL이 됨:
--   SELECT CASE
--       WHEN country IN ('KR','JP','CN','TW','HK','SG') THEN 'APAC'
--       WHEN country IN ('US','CA','MX')                THEN 'NA'
--       WHEN country IN ('GB','FR','DE','IT','ES','NL') THEN 'EU'
--       ELSE 'OTHER'
--   END AS region FROM ...
