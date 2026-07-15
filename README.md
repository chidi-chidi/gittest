  # dbt 예시 프로젝트 (학습용 · DuckDB 로컬 실행)

  > git(clone/commit/push/merge) + dbt 실습용 repo.
  > 별도 DB 서버 없이 **DuckDB**로 바로 `dbt seed → run → test`가 돌아감.

  ## 폴더 구조

  gittest/
  ├── .github/
  │   └── workflows/
  │       └── dbt_ci.yml          ← PR 오픈 시 dbt build 자동 실행 (CI)
  ├── dbt_project.yml             ← [핵심] 프로젝트 루트 설정. 이 파일이 있으면 dbt 프로젝트
  ├── profiles.yml                ← DB 접속 정보 (DuckDB). 보통 ~/.dbt/profiles.yml에 둠
  ├── packages.yml                ← 외부 패키지 선언 (dbt_utils, audit_helper)
  ├── models/
  │   ├── sources.yml             ← 원천 테이블 등록
  │   ├── staging/                ← staging 레이어 (타입 정리, 컬럼명 표준화)
  │   │   ├── stg_orders.sql
  │   │   ├── stg_customers.sql
  │   │   ├── stg_store_sales.sql
  │   │   ├── stg_stores.sql
  │   │   └── schema.yml          ← 모델 테스트/문서
  │   └── marts/                  ← mart 레이어 (비즈니스 마트)
  │       ├── fct_orders_daily.sql        ← incremental + backfill 지원
  │       ├── fct_store_sales_daily.sql   ← 일별 매장 매출 집계
  │       ├── dim_customers.sql
  │       ├── revenue_by_region.sql
  │       └── schema.yml
  ├── macros/                     ← 재사용 가능한 SQL 조각
  │   ├── country_to_region.sql
  │   └── net_revenue.sql
  ├── analyses/                   ← 쿼리 결과 확인용 (테이블 생성 안 함)
  │   └── audit_orders.sql        ← audit_helper로 모델 변경 전후 diff 비교
  ├── snapshots/                  ← SCD2 이력 관리
  │   └── customers_snapshot.sql
  ├── tests/                      ← singular test (비즈니스 로직 검증)
  │   └── assert_completed_orders_positive_amount.sql
  └── seeds/                      ← CSV 시드 데이터 (로컬 실습용 원천 데이터)
      ├── orders.csv
      ├── customers.csv
      ├── stores.csv
      ├── store_sales.csv
      ├── country_region_map.csv
      └── customer_segment_threshold.csv

  ## 데이터 흐름

  [원천 테이블]                    [staging 레이어]                [mart 레이어]
  raw.orders          ────→  stg_orders        ────→  fct_orders_daily (incremental)
  raw.customers       ────→  stg_customers     ────→  dim_customers
  raw.store_sales     ────→  stg_store_sales   ────→  fct_store_sales_daily (incremental)
  raw.stores          ────→  stg_stores        ─┘
  (sources.yml)              (view)                   (table / incremental)

  ## 주요 명령어

  ```bash
  # 기본 작업 루프
  dbt deps                             # packages.yml 패키지 설치
  dbt seed                             # CSV 시드 데이터 적재
  dbt run                              # 모든 모델 빌드
  dbt test                             # 모든 테스트 실행
  dbt build                            # seed + run + test 한 번에 (실무 권장)

  # 선택적 실행
  dbt run -s stg_orders                # 특정 모델만
  dbt run -s +fct_orders_daily         # 이 모델 + 상위 의존 모델 전부
  dbt run -s tag:daily                 # 태그로 묶어서 실행

  # Backfill (날짜 범위 지정 재처리)
  dbt run -s fct_orders_daily \
    --vars '{"start_date":"2024-01-01","end_date":"2024-01-31"}'

  # 컴파일된 실제 SQL 확인 (Jinja 펼쳐진 결과)
  dbt compile -s fct_orders_daily

  # 문서/lineage 시각화
  dbt docs generate && dbt docs serve  # localhost:8080 에서 확인

  CI/CD

  PR을 main으로 올리면 GitHub Actions가 자동으로 dbt build를 실행함.
  테스트 실패 시 머지 차단 (branch protection ruleset 설정).

  PR 오픈 → GitHub Actions 트리거 → dbt build 실행
    → PASS: 머지 가능 ✅
    → FAIL: 머지 차단 ❌

  Airflow와의 관계

  운영 환경에선 Airflow가 위 명령어들을 매일 새벽에 호출함:
  # Airflow DAG 안 (예시)
  dbt_run = BashOperator(
      task_id='dbt_run_daily',
      bash_command='dbt run --select tag:daily --target prod'
  )

  # backfill 시 날짜 주입
  dbt_backfill = BashOperator(
      task_id='dbt_backfill',
      bash_command='dbt run -s fct_orders_daily --target prod --vars
                    {"start_date":"{{ ds }}", "end_date":"{{ds }}"}
                    '
  )

  즉, dbt 프로젝트(SQL+YAML) 자체는 본인이 작성하고,
  그걸 매일 실행하는 스케줄러는 Airflow가 담당.
  코드 배포(git push) ≠ 데이터 실행(Airflow 트리거).