# dbt 치트시트 (실무 진입용)

## 1. CLI 명령어

```bash
# 기본
dbt run                              # 모든 모델 빌드
dbt test                             # 모든 테스트 실행
dbt build                            # run + test (의존성 순서, 실패 시 하위 SKIP) ★ 권장
dbt compile                          # SQL만 컴파일 (실행 X). Jinja 결과 보기
dbt seed                             # CSV 적재
dbt snapshot                         # SCD2 스냅샷 실행
dbt clean                            # target/, dbt_packages/ 삭제

# 모델 선택 (--select / -s)
dbt build -s stg_orders              # 단일 모델
dbt build -s stg_orders+             # 모델 + 그 아래(downstream) 전부
dbt build -s +stg_orders             # 모델 + 그 위(upstream) 전부
dbt build -s @stg_orders             # 그 위 + 위에서 다시 아래까지
dbt build -s tag:daily               # 태그로 묶어서
dbt build -s path:models/marts       # 폴더 단위
dbt build -s state:modified+         # 변경된 모델 + 하위 (Slim CI)
dbt build -s result:error+           # 직전 실패만 다시
dbt build --exclude tag:experimental # 제외

# 운영
dbt run --target prod                # profiles.yml의 prod 환경 사용
dbt build --full-refresh             # incremental 모델 전체 재빌드
dbt build --threads 8                # 병렬 실행 수

# 문서
dbt docs generate                    # 문서 빌드
dbt docs serve                       # 로컬 웹사이트로 열기

# 패키지
dbt deps                             # packages.yml의 의존성 설치
```

## 2. Materialization 4종

| 종류 | 동작 | 언제 씀 |
|---|---|---|
| `view` | 매번 SELECT만 실행되는 뷰 | staging, 가벼운 변환 (기본값) |
| `table` | 매번 CREATE TABLE AS 로 재생성 | mart, 자주 조회되는 작은~중간 테이블 |
| `incremental` | 새 데이터만 추가/머지 | 큰 fact 테이블 |
| `ephemeral` | 테이블 안 만들고 CTE로 인라인 | 중간 단계 임시 변환 |

```sql
{{ config(materialized='incremental') }}
```

## 3. 자주 쓰는 config 옵션

```sql
{{ config(
    materialized='incremental',
    unique_key='order_id',                       -- MERGE 키 (없으면 append만)
    incremental_strategy='merge',                -- merge / append / delete+insert / insert_overwrite
    on_schema_change='append_new_columns',       -- fail / ignore / append_new_columns / sync_all_columns
    schema='marts',                              -- 출력 스키마
    alias='daily_orders',                        -- 파일명과 다른 테이블명
    tags=['daily', 'finance'],                   -- 그룹핑
    enabled=true,                                -- 환경별 비활성화에 활용
    pre_hook='ANALYZE {{ this }}',               -- 빌드 전 SQL
    post_hook='GRANT SELECT ON {{ this }} TO analyst_role',  -- 빌드 후 SQL
    grants={'select': ['analyst_role']},         -- 권한 (post_hook 대체)

    -- BigQuery 전용
    partition_by={'field': 'order_date', 'data_type': 'date'},
    cluster_by=['customer_id'],

    -- Snowflake 전용
    cluster_by=['order_date']
) }}
```

## 4. Jinja 핵심

### 참조 함수
```sql
{{ ref('stg_orders') }}                    -- 다른 모델 참조
{{ source('raw', 'orders') }}              -- 원천 테이블 참조
{{ var('start_date') }}                    -- dbt_project.yml의 변수
{{ var('end_date', '2099-12-31') }}        -- 기본값 지정
{{ env_var('DBT_PASSWORD') }}              -- 환경 변수
{{ this }}                                 -- 현재 모델 (incremental에서 유용)
{{ target.name }}                          -- 현재 target ('dev' / 'prod')
{{ target.schema }}                        -- 현재 스키마
```

### 제어 흐름
```sql
{% if is_incremental() %}                  -- incremental 첫 실행 후만 true
  WHERE order_at > (SELECT MAX(order_at) FROM {{ this }})
{% endif %}

{% if target.name == 'prod' %}             -- 환경 분기
  -- 운영에서만 실행
{% endif %}

{% for col in ['col_a', 'col_b', 'col_c'] %}
  SUM({{ col }}) AS sum_{{ col }}{% if not loop.last %},{% endif %}
{% endfor %}

{% set my_var = 'hello' %}                 -- 변수 할당
```

### 매크로
```sql
-- macros/cents_to_dollars.sql
{% macro cents_to_dollars(column_name, decimal_places=2) %}
    ROUND({{ column_name }} / 100.0, {{ decimal_places }})
{% endmacro %}

-- 사용
SELECT {{ cents_to_dollars('amount_cents') }} AS amount_dollars FROM ...
```

## 5. 테스트

### Generic test (schema.yml)
```yaml
columns:
  - name: order_id
    tests:
      - not_null
      - unique
      - relationships:
          to: ref('stg_customers')
          field: customer_id
      - accepted_values:
          values: ['pending', 'completed', 'cancelled']
      - dbt_utils.expression_is_true:           # dbt_utils 패키지
          expression: ">= 0"
```

### Singular test (tests/*.sql)
```sql
-- tests/some_business_rule.sql
SELECT * FROM {{ ref('fct_orders_daily') }}
WHERE revenue < 0
-- 0건 반환되면 PASS
```

### 테스트 옵션
```yaml
tests:
  - not_null:
      severity: warn         # error(기본) / warn — warn은 실패해도 빌드 계속
      where: "status = 'completed'"   -- 조건부 테스트
      config:
        store_failures: true # 실패한 행 DW에 저장
```

## 6. Sources (원천 등록)

```yaml
# models/sources.yml
version: 2
sources:
  - name: raw
    database: my_warehouse
    schema: raw_data
    freshness:
      warn_after: {count: 12, period: hour}
      error_after: {count: 24, period: hour}
    loaded_at_field: _loaded_at
    tables:
      - name: orders
        identifier: raw_orders_v2     # 실제 DW 테이블명이 다를 때
        columns:
          - name: order_id
            tests: [not_null, unique]
```

```bash
dbt source freshness                    # 신선도 체크
```

## 7. Snapshot (SCD Type 2)

원본 데이터의 변경 이력을 추적할 때:

```sql
-- snapshots/customers_snapshot.sql
{% snapshot customers_snapshot %}
  {{
    config(
      target_schema='snapshots',
      unique_key='customer_id',
      strategy='timestamp',
      updated_at='updated_at'
    )
  }}
  SELECT * FROM {{ source('raw', 'customers') }}
{% endsnapshot %}
```

```bash
dbt snapshot                            # 변경 감지 후 이력 적재
```

## 8. dbt_utils 패키지 — 자주 쓰는 매크로

```yaml
# packages.yml
packages:
  - package: dbt-labs/dbt_utils
    version: 1.1.1
```

```bash
dbt deps   # 설치
```

| 매크로 | 용도 |
|---|---|
| `{{ dbt_utils.surrogate_key(['col_a', 'col_b']) }}` | 컬럼 합쳐서 해시 PK 생성 |
| `{{ dbt_utils.star(from=ref('stg_orders'), except=['internal_col']) }}` | `SELECT *` 에서 일부 컬럼 제외 |
| `{{ dbt_utils.date_spine(start_date='2024-01-01', end_date='2024-12-31') }}` | 날짜 시리즈 생성 |
| `{{ dbt_utils.pivot('status', ['pending', 'completed']) }}` | 피벗 |
| `{{ dbt_utils.unpivot(...) }}` | 언피벗 |
| `{{ dbt_utils.get_column_values(table=ref('x'), column='y') }}` | 컬럼 unique 값 리스트 (for문에 활용) |
| `{{ dbt_utils.deduplicate(...) }}` | 중복 제거 |

### 테스트 매크로
```yaml
tests:
  - dbt_utils.unique_combination_of_columns:
      combination_of_columns: [order_date, region]
  - dbt_utils.expression_is_true:
      expression: "revenue >= 0"
  - dbt_utils.accepted_range:
      min_value: 0
      max_value: 100
  - dbt_utils.equal_rowcount:
      compare_model: ref('stg_orders_raw')
```

## 9. 프로젝트 구조 (모범 사례)

```
my_dbt_project/
├── dbt_project.yml
├── packages.yml                        # 외부 패키지
├── profiles.yml                        # 보통 ~/.dbt/ 에 위치
│
├── models/
│   ├── staging/                        # 원천 가벼운 정리 (view)
│   │   ├── _sources.yml                # 원천 등록
│   │   ├── _stg__models.yml            # 모델 테스트/문서
│   │   ├── stg_orders.sql
│   │   └── stg_customers.sql
│   │
│   ├── intermediate/                   # 중간 변환 (ephemeral or view)
│   │   ├── _int__models.yml
│   │   └── int_orders_joined.sql
│   │
│   └── marts/                          # 비즈니스 마트 (table / incremental)
│       ├── finance/
│       │   ├── _finance__models.yml
│       │   ├── fct_orders.sql
│       │   └── dim_customers.sql
│       └── product/
│           └── ...
│
├── macros/                             # 재사용 SQL
├── tests/                              # singular test
├── seeds/                              # CSV
├── snapshots/                          # SCD2
└── analyses/                           # 일회성 분석 SQL (배포 안 함)
```

### 명명 규칙 (관례)
- `stg_<source>__<table>` — staging
- `int_<entity>_<verb>ed` — intermediate (예: `int_orders_joined`)
- `fct_<entity>` — fact 테이블
- `dim_<entity>` — dimension 테이블

## 10. 환경 분기 패턴

### profiles.yml로 dev/prod 분리
```bash
dbt run --target dev    # 개발
dbt run --target prod   # 운영
```

### SQL 안에서 분기
```sql
SELECT * FROM {{ ref('stg_orders') }}
{% if target.name == 'dev' %}
  LIMIT 10000                          -- 개발은 샘플만
{% endif %}
```

### dbt_project.yml로 환경별 설정
```yaml
models:
  my_analytics:
    marts:
      +materialized: "{{ 'view' if target.name == 'dev' else 'table' }}"
```

## 11. 자주 만나는 패턴

### Incremental 안전마진
```sql
{% if is_incremental() %}
  WHERE ordered_at > (
    SELECT MAX(ordered_at) - INTERVAL '3 days' FROM {{ this }}
  )
{% endif %}
```

### Source freshness 자동 체크
```bash
dbt source freshness
# CI에 넣어두면 원천 데이터 지연 자동 감지
```

### Slim CI (변경분만 빌드)
```bash
# main 브랜치의 manifest를 기준으로 변경된 것만
dbt build -s state:modified+ --defer --state ./prod-manifest
```

### 모델 1개를 여러 형태로 (alias)
```sql
{{ config(alias='orders_for_reporting') }}
-- 파일명은 fct_orders.sql이지만 DW에는 orders_for_reporting으로 만들어짐
```

## 12. 디버깅

```bash
dbt compile -s fct_orders_daily          # Jinja 펼친 SQL 보기
                                         # → target/compiled/...sql 에 저장됨
cat target/compiled/my_analytics/models/marts/fct_orders_daily.sql

dbt debug                                # 접속 정보, 환경 점검
dbt parse                                # 빠른 파싱 검증
dbt --log-level debug run                # 상세 로그
```

## 13. 운영 베스트 프랙티스

1. **`dbt build` 쓰기** (run+test 분리하지 말기)
2. **태그로 스케줄 그룹핑** — `tag:daily`, `tag:hourly` 등으로 Airflow와 매핑
3. **incremental 모델엔 `unique_key` + `on_schema_change` 챙기기**
4. **staging은 무조건 1:1 view** — 원천 한 테이블당 stg 한 개
5. **mart에서 직접 source 참조 금지** — 반드시 stg 거치기
6. **Slim CI 도입** — PR마다 풀빌드 말고 변경분만
7. **freshness + dbt_utils 테스트** — 데이터 품질 안전망

---

## 핵심 학습 우선순위

> **70% 일을 하게 해주는 20% 기능**:
> `ref()`, `source()`, `{{ config() }}`, `materialized` 4종, `is_incremental()`, generic test (`not_null`/`unique`/`relationships`), `dbt build`, `--select` 기본

이것만 알아도 dbt 프로젝트에 충분히 기여할 수 있어요. 나머지는 필요할 때 위 치트시트를 검색하면서 추가.
