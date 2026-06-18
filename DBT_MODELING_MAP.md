# dbt 데이터 모델링 지도 (기능 카테고리 정리)

> dbt가 data modeling을 위해 제공하는 기능들을 카테고리별로 정리.
> "무엇이 가능한지에 대한 지도" — 세부 문법은 그때그때 찾고, 이 지도로 방향을 잡는다.
> (✅ = 이 repo 실습에서 직접 써본 것)

---

## A. 모델링 빌딩블록 — "무엇을 만드나"

| 기능 | 설명 | 실습 |
|---|---|---|
| **Models** (`.sql`) | SELECT 하나 = 테이블/뷰 하나. 모델링의 기본 단위 | ✅ |
| **Materializations** | 물리적 저장 방식: `view` / `table` / `incremental` / `ephemeral` / `materialized_view` | ✅ |
| **Seeds** | CSV를 테이블로. 작은 참조/룩업 데이터 | ✅ |
| **Sources** | 원천 테이블 등록 → `source()`로 참조, freshness 체크 | ✅ |
| **Snapshots** | **SCD Type 2** — 원천 값 변경 이력 추적 (느린 변경 차원) | |
| **Analyses** | 배포 안 하는 일회성 분석 SQL (Jinja는 사용) | |

## B. 모델 간 구조/관계 — "어떻게 엮나"

| 기능 | 설명 | 실습 |
|---|---|---|
| **`ref()` / `source()`** | 모델·원천 참조 → dbt가 **의존성(DAG)** 자동 구성, 실행 순서 결정 | ✅ |
| **Lineage 그래프** | DAG 시각화 (`dbt docs generate && dbt docs serve`) | ✅ |
| **레이어링 방법론** | dbt 권장 구조: **staging → intermediate → marts** (정리→중간변환→비즈니스마트) | ✅ (stg/marts) |
| **Dimensional modeling** | fact(`fct_`)/dimension(`dim_`) 패턴. 강제는 아니고 관례 | ✅ |

## C. 로직 재사용/추상화 — "DRY하게"

| 기능 | 설명 | 실습 |
|---|---|---|
| **Macros** | 재사용 SQL 조각 (Jinja 함수) | ✅ |
| **Jinja** | 제어흐름(`if`/`for`), 변수(`set`), 동적 SQL 생성 | ✅ |
| **Variables** (`var`) | 환경/실행별 파라미터 (예: `start_date`, backfill 범위) | ✅ |
| **Packages** | 외부 매크로 패키지: `dbt_utils`(surrogate_key, star, date_spine…), `audit_helper`, `dbt_expectations` | |

## D. 데이터 품질/검증 — "맞는지 보장"

| 기능 | 설명 | 실습 |
|---|---|---|
| **Generic tests** | `not_null` / `unique` / `relationships` / `accepted_values` (schema.yml) | ✅ |
| **Singular tests** | 커스텀 SQL 테스트 (0건이면 PASS) | ✅ |
| **Unit tests** (1.8+) | mock 입력 → 기대 출력 비교. **로직 단위 테스트** (실제 데이터 불필요) | |
| **Model contracts** | 컬럼/타입을 YAML에 선언하고 **강제** (어기면 빌드 실패) | |

## E. 물리적 모델링 — "저장 방식 제어" (전부 `config`)

| 기능 | 설명 | 실습 |
|---|---|---|
| **`materialized`** | A의 materialization 종류 지정 | ✅ |
| **`partition_by` / `cluster_by`** | 파티셔닝·클러스터링 (웨어하우스 전용, DuckDB엔 없음) | |
| **`incremental_strategy`** | `append`/`merge`/`delete+insert`/`insert_overwrite` + `unique_key`, `on_schema_change` | ✅ (일부) |
| **Hooks / grants / indexes** | `pre_hook`/`post_hook`, 권한 부여, 인덱스 | |

## F. 거버넌스/메타데이터 모델링 — "조직 규모에서" (1.5+)

| 기능 | 설명 |
|---|---|
| **Documentation** | description, `persist_docs`(DB COMMENT로 반영), docs blocks |
| **Model versions** | 모델 v1/v2 공존시키며 안전하게 마이그레이션 |
| **Groups & access** | 모델 `public`/`private`/`protected` → 팀 간 의존성 통제 |
| **Exposures** | 이 모델을 쓰는 **하류 소비처**(대시보드/ML) 등록 → lineage 끝까지 연결 |

## G. 의미론적 모델링 — "비즈니스 지표" (Semantic Layer / MetricFlow, 1.6+)

| 기능 | 설명 |
|---|---|
| **Semantic models** | 테이블 위에 entity / dimension / measure 정의 |
| **Metrics** | "매출", "활성고객수" 같은 지표를 **한 번 정의 → 어디서나 일관 조회** |
| 목적 | BI마다 지표 정의가 제각각인 문제 해결 (단일 진실의 원천) |

---

## 모델링 성숙도 순서

```
1단계 (이 repo에서 한 것): models + materializations + ref/source + seeds + 기본 tests + macros
                          → staging/marts 레이어로 fact/dim 만들기  ← 여기까지면 실무 기여 충분

2단계 (품질·규모):        incremental 전략 + contracts + unit tests + packages(dbt_utils)

3단계 (거버넌스):         versions + groups/access + exposures + snapshots

4단계 (의미론):           Semantic Layer / Metrics
```

> 핵심: **A~D가 모델링의 80%** (이 repo에서 거의 다 다룸). E는 성능/운영, F는 조직 규모, G는 지표 표준화 — 필요해질 때 하나씩 얹으면 된다.

---

## 다음에 해볼 것 (TODO)

- [ ] **Snapshots** — 고객 정보 변경 이력(SCD2) 모델링 직접 만들어보기
- [ ] **packages** — `dbt_utils` 설치해서 surrogate_key/star 등 써보기
- [ ] **Semantic Layer** — 매출 metric 정의해보기
- [ ] **model contract** — dim_customers에 타입 계약 걸어보기
