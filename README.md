# dbt 예시 프로젝트 (학습용 · DuckDB 로컬 실행)

> git(clone/commit/push/merge) + dbt 실습용 repo.
> 별도 DB 서버 없이 **DuckDB**로 바로 `dbt seed → run → test`가 돌아감.

## 폴더 구조

```
gittest/
├── dbt_project.yml         ← [핵심] 프로젝트 루트 설정. 이 파일이 있으면 dbt 프로젝트
├── profiles.yml            ← DB 접속 정보 (DuckDB). 보통 ~/.dbt/profiles.yml에 둠
├── models/                 ← SQL 모델들이 사는 곳
│   ├── sources.yml         ← 원천 테이블 등록 (seed로 적재한 orders/customers)
│   ├── staging/            ← staging 레이어 (가벼운 정리)
│   │   ├── stg_orders.sql
│   │   ├── stg_customers.sql
│   │   └── schema.yml      ← 모델 테스트/문서
│   └── marts/              ← mart 레이어 (비즈니스 마트)
│       ├── fct_orders_daily.sql
│       ├── dim_customers.sql
│       └── schema.yml
├── macros/                 ← 재사용 가능한 SQL 조각
│   └── country_to_region.sql
├── tests/                  ← 커스텀 테스트 SQL
└── seeds/                  ← CSV 시드 데이터
    ├── orders.csv          ← 원천 주문 데이터 (DuckDB 실습용)
    ├── customers.csv       ← 원천 고객 데이터
    ├── country_region_map.csv
    └── customer_segment_threshold.csv
```

## 데이터 흐름

```
[원천 테이블]                          [staging 레이어]                  [mart 레이어]
raw.orders          ─────→  stg_orders   ─────→  fct_orders_daily
raw.customers       ─────→  stg_customers ─────→ dim_customers
(sources.yml)               (view)                (table / incremental)
```

## 주요 명령어

```bash
dbt run                              # 모든 모델 빌드
dbt run --select stg_orders          # 특정 모델만
dbt run --select +fct_orders_daily   # 이 모델 + 의존하는 모든 상위 모델
dbt run --select tag:daily           # 태그로 묶어서 실행 (Airflow에서 활용)

dbt test                             # 모든 테스트 실행
dbt build                            # run + test 합친 명령 (실무 권장)

dbt docs generate && dbt docs serve  # 자동 생성된 문서 사이트 열기
```

## Airflow와의 관계

운영 환경에선 Airflow가 위 명령어들을 매일 새벽에 호출해줌:
```python
# Airflow DAG 안 (예시)
dbt_run = BashOperator(
    task_id='dbt_run_daily',
    bash_command='dbt run --select tag:daily --target prod'
)
```

즉, **dbt 프로젝트(SQL+YAML) 자체는 본인이 작성**하고,
**그걸 매일 실행하는 스케줄러**는 Airflow가 담당.
