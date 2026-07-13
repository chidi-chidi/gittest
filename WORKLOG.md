# 작업 로그 & 셋업 가이드 (dbt + git 실습)

> 이 repo는 **git(clone/commit/push/merge) + dbt 실습용**이다.
> 별도 DB 서버 없이 **DuckDB**로 `dbt build`(seed→run→test)가 로컬에서 바로 돌아간다.
> 다른 랩탑에서 `git pull` 후 아래 "환경 재현"만 따라하면 똑같이 동작한다.

---

## 진행 상황 (이어서 할 때 여기부터)

- ✅ 1일차: 환경 구축(uv+Py3.12, dbt-duckdb) → 프로젝트 DuckDB 변환 → git+dbt PR 흐름(브랜치→commit→push→PR→merge) → DuckDB 직접 쿼리 → docs/lineage → 문서화(WORKLOG, DBT_MODELING_MAP)
- ✅ 2일차: **Snapshots(SCD2)** 실습 완료 — `snapshots/customers_snapshot.sql`(check 전략, country 추적). `dbt snapshot`으로 초기 기록 → seed 변경 → 재snapshot으로 이력(valid_from/valid_to) 쌓이는 것 확인.
- ✅ 3일차: **dbt_utils 패키지** — `packages.yml`+`dbt deps`로 설치(1.4.0). `generate_surrogate_key`로 fct_orders_daily에 `order_region_key` 대리키 추가(CTE로 감싸서), `unique_combination_of_columns` 테스트 추가, `star`로 `orders_public`(order_amount 제외) 모델 생성. full-refresh로 incremental 재빌드.
- ✅ 4일차: **model contract** — dim_customers에 `contract: enforced` + 컬럼별 data_type 선언(타입 어기면 빌드 실패 확인). **Semantic Layer/MetricFlow** — `dbt-metricflow` 설치, `semantic_orders.yml`(semantic model + metric: revenue/order_count), `metricflow_time_spine`(dbt_utils.date_spine로 날짜축) 추가. `mf query --metrics ... --group-by ...`로 GROUP BY 없이 지표 조회. (개념 위주로 맛봄 — 세부는 다음에)
- ✅ 5일차: **macro 실습** — `macros/net_revenue.sql`(completed만 합산하는 "순매출" 매크로) + `models/marts/revenue_by_region.sql`(매크로로 지역별 net_revenue 컬럼). compiled로 `SUM(CASE WHEN...)` 펼쳐짐 확인. 교훈: 계산 로직 재사용은 macro의 영역(semantic layer는 조회용).
  - 겪은 함정: `git restore`로 seed 파일은 원복됐지만 `dbt seed`를 안 돌려 DB엔 옛 데이터(1번 US) 남아있었음 → `dbt seed && dbt build`로 동기화. **"파일 ≠ DB 데이터, seed는 다시 돌려야 반영"**
---

## 앞으로 할 일 (DA→DAE 전환 실습 로드맵)

> 배경: DA 출신, 마트 쿼리 경험 있음. dbt 운영 / git 협업은 이번에 처음 익히는 중.
> 목표: "SQL 잘 짜기" → "SQL이 안전하게 운영되는 구조 만들기"

- ✅ **6일차: Incremental + Backfill 실습**
  - `fct_orders_daily`에 `delete+insert` 전략 + `--vars`로 날짜 범위 주입하는 backfill 분기 추가
  - `end_date` 없으면 기존 3일치 재처리(일반 운영), 두 vars 모두 있으면 backfill 모드로 분기
  - `dbt compile`로 Jinja가 모드별로 다른 SQL 생성하는 것 확인
  - 겪은 함정: config 블록 안에 `--` 주석 쓰면 Jinja 파싱 에러. config 블록은 Python 영역.
  - 겪은 함정: `dbt_project.yml`의 `vars`에 `start_date`만 있고 `end_date` 없으면 조건 분기 오작동 → 두 vars 모두 체크하는 조건으로 수정
  - 배운 개념: git push(코드 배포) ≠ backfill 실행(Airflow 수동 트리거). DAE는 "할 수 있는 구조"를 만들고, 실행은 DE/Airflow가 담당.

  - ✅ **7일차: git 머지 컨플릭트 해결 연습**
    - 같은 파일(stg_orders.sql)을 두 브랜치에서 다르게 수정해서 충돌 상황 재현
    - Fast-forward(충돌 없음) vs CONFLICT(충돌) 차이 확인
    - 충돌 마커(<<<<<<< / ======= / >>>>>>>) 직접 편집해서 두 컬럼 모두 살리는 방식으로 해결
    - 배운 개념: 충돌은 git이 자동 해결 못하는 상황, 사람이 직접 "어떤 내용을 남길지" 결정해야 함
    - 실무 팁: 같은 파일을 동시에 건드리는 브랜치가 많을수록 충돌 빈도 높아짐 → 브랜치 단위를 작게 유지하는 게   
  중요

  - ✅ **8일차: GitHub Actions CI 세팅**
    - `.github/workflows/dbt_ci.yml` 작성 — PR 오픈 시 자동으로 dbt build 실행
    - 겪은 함정: GitHub PAT에 workflow 스코프 없으면 push 거절됨 → 토큰 권한 추가
    - CI 통과 후 머지하는 전체 흐름 체험 (PR → Actions 자동 실행 → 초록불 → 머지)
    - 배운 개념: .github/workflows/ 폴더를 GitHub가 자동 인식. PR마다 서버 띄워서 dbt build 돌려줌
    - 배운 개념: origin = GitHub 저장소 별명, main = 브랜치 이름. 완전히 다른 개념
    - branch protection ruleset 설정 — CI 실패 시 머지 버튼 차단 확인
    - 겪은 함정: ruleset 만들어도 Enforcement가 Disabled면 적용 안 됨 → Active로 변경 필요

- ⬜ **9일차: 테스트 심화 + audit_helper**
  - singular test(커스텀 SQL 테스트) 직접 작성
  - `audit_helper`로 모델 변경 전후 데이터 diff 검증

- ⬜ **최종: 실제 업무 쿼리 → dbt 이식 미니 프로젝트**
  - 현재 DA로 쓰는 마트 쿼리를 staging/mart 레이어로 설계해서 dbt 프로젝트화

---

## 0. 다른 랩탑에서 시작하기 (환경 재현) ★중요

`venv/`와 `dev.duckdb`는 git에 안 올라간다(.gitignore). 그래서 새 PC에선 환경을 다시 만들어야 한다.

```powershell
# 1) repo 클론
git clone https://github.com/chidi-chidi/gittest.git
cd gittest

# 2) uv 설치 (없으면) — Python 버전/패키지 관리 도구
pip install uv

# 3) Python 3.12 가상환경 생성 + 활성화
#    ※ dbt는 Python 3.14와 호환 안 됨 → 반드시 3.12 (uv가 알아서 받아옴)
uv python install 3.12
uv venv venv --python 3.12
.\venv\Scripts\Activate.ps1          # 프롬프트에 (venv) 붙으면 성공

# 4) dbt(DuckDB 어댑터) 설치
uv pip install dbt-duckdb
# (선택) semantic layer 쓰려면 — mf 명령 제공
uv pip install --python venv/Scripts/python.exe dbt-metricflow

# 5) 한글 Windows 인코딩 문제 방지 (cp949 → UTF-8)
#    Activate.ps1에 이미 추가돼 있으면 자동. 아니면 세션마다:
$env:PYTHONUTF8 = "1"

# 6) 동작 확인
dbt debug        # All checks passed! 나오면 OK
dbt build        # seed+run+test 전부 → PASS=31 이면 성공
```

> macOS/Linux면 활성화만 `source venv/bin/activate`로 바뀌고 나머지는 동일.

---

## 1. 프로젝트 개요

- dbt 프로젝트명: `my_analytics`, 어댑터: **DuckDB** (`dev.duckdb` 파일이 곧 DB)
- `profiles.yml`이 프로젝트 폴더 안에 있음 (보통은 `~/.dbt/`에 두지만 학습용으로 동봉)
- 원래 Postgres 예제였으나 로컬 실행 위해 DuckDB로 변환함

### 데이터 흐름 (DAG)
```
seeds (orders.csv, customers.csv)        ← 원천 데이터 (DuckDB용으로 직접 채움)
   │
   ▼  source('raw', ...)
stg_orders, stg_customers  (view, main_staging)   ← 가벼운 정리 + region 매핑(매크로)
   │
   ▼  ref(...)
dim_customers (table),  fct_orders_daily (incremental)  (main_marts)
   │
   ▼
tests: not_null/unique/relationships/accepted_values + singular 2개
```

### 스키마 위치 (DuckDB)
| 스키마 | 들어있는 것 |
|---|---|
| `main` | seeds (orders, customers, country_region_map, customer_segment_threshold) |
| `main_staging` | stg_orders, stg_customers (view) |
| `main_marts` | dim_customers, fct_orders_daily (table/incremental) |

---

## 2. 자주 쓰는 명령어

```powershell
# dbt 작업 루프
dbt seed                         # CSV 적재
dbt run                          # 모델 빌드
dbt test                         # 테스트
dbt build                        # 위 3개 한 번에 (실무 권장)
dbt run -s dim_customers         # 특정 모델만
dbt run --full-refresh -s fct_orders_daily   # incremental 전체 재빌드

# lineage 그래프 시각화 (웹)
dbt docs generate                # 문서/카탈로그 생성
dbt docs serve                   # localhost:8080 에 그래프 사이트 열림 (Ctrl+C로 종료)

# 컴파일된 실제 SQL 보기
dbt compile -s dim_customers     # target/compiled/.../dim_customers.sql 생성
```

### DuckDB 직접 쿼리 (venv 켜진 채, gittest 폴더에서, dbt 안 돌릴 때)
```powershell
# 테이블 목록
python -c "import duckdb; print(duckdb.connect('dev.duckdb').sql('SHOW ALL TABLES'))"
# dim_customers 조회
python -c "import duckdb; print(duckdb.connect('dev.duckdb').sql('SELECT customer_id, country, region, lifetime_value, avg_order_value, customer_segment FROM main_marts.dim_customers ORDER BY lifetime_value DESC'))"
# 컬럼 타입 확인
python -c "import duckdb; print(duckdb.connect('dev.duckdb').sql('DESCRIBE main_marts.dim_customers'))"
```
> ⚠️ DuckDB 파일은 한 번에 한 프로세스만 연다. dbt 실행 중엔 쿼리 안 됨.

---

## 3. git + dbt 협업 워크플로우 (실습한 흐름)

```
git switch -c feature/xxx        # 작업 브랜치 생성 (+이동). -c = create
  └ 모델(.sql) 수정 + dbt run으로 dev 확인
git add <파일> && git commit -m "feat: ..."
git push -u origin feature/xxx   # GitHub에 브랜치 업로드 → PR 링크 출력됨
  └ GitHub 웹에서 PR 생성 → Merge
git switch main && git pull      # 로컬 main 동기화
git branch -d feature/xxx        # 다 쓴 로컬 브랜치 정리
```
- `push` ≠ PR. PR은 "이 브랜치를 main에 합쳐도 될까?" 요청. main에 직접 push하면 PR 없이 끝남.
- 실무는 main 직접 push 막고(branch protection) 무조건 PR 거침.

---

## 4. 겪은 트러블슈팅 (다시 만나면 참고)

| 증상 | 원인 | 해결 |
|---|---|---|
| dbt 설치는 됐는데 `dbt --version`에서 mashumaro `UnserializableField` 에러 | Python 3.14가 dbt와 비호환 | Python **3.12**로 venv 재생성 (uv 사용) |
| `py -3.12 -m venv` 실패 (파일 못 찾음) | 런처엔 등록됐지만 실제 3.12 exe 없음(깨진 설치) | uv로 설치: `uv python install 3.12` |
| Python 3.12 MSI 설치 실패 (0x80070643) | 이전 깨진 설치 잔재 | MSI 대신 uv로 설치 (MSI 회피) |
| `dbt init`/명령에서 `cp949 codec can't decode` | 한글 Windows 기본 인코딩(cp949)이 UTF-8 파일 못 읽음 | `$env:PYTHONUTF8="1"` (Activate.ps1에 추가해둠) |
| dbt가 엉뚱한 부모 폴더의 dbt_project.yml을 찾음 | repo 상위 폴더에 또 다른 dbt 프로젝트 존재 | dbt 프로젝트를 repo 안으로 이동 (부모엔 dbt_project.yml 없게) |
| `DATE(...)` 함수 에러 | DuckDB엔 DATE() 함수 없음 | `CAST(... AS DATE)` 사용 |

---

## 5. 배운 핵심 개념 (요약)

- **DuckDB** = "분석용 SQLite". 서버 없이 파일 하나가 DB. 실무에선 BigQuery/Snowflake/Redshift/Impala 등으로 대체, dbt 코드는 거의 그대로 재사용.
- **Materialization 4종**: `view`(쿼리만) / `table`(매번 재생성) / `incremental`(새 데이터만 추가) / `ephemeral`(CTE 인라인).
- **선언형**: 사람은 SELECT(결과 모습)만 쓰고, `CREATE/ALTER/INSERT` DDL·DML은 dbt가 생성·실행. (명령형으로 직접 ALTER 안 침)
- **table 모델은 drop&recreate** 해도 상위에서 재계산되니 데이터 안 잃음. 못 만드는 과거 데이터는 `incremental`로 보존.
- **컬럼 타입**은 SELECT 표현식/CAST가 결정(CTAS 추론). 엄격히 잡으려면 **model contract**(`data_type` 선언·강제).
- **partition/cluster**는 SELECT가 아니라 `config`(SQL/schema.yml/project.yml)에 선언 → dbt가 DDL에 박음. (웨어하우스 전용, DuckDB엔 없음)
- **backfill**: `incremental_strategy='insert_overwrite'` + 날짜 `var`로 범위 받기 → **멱등**하게 파티션 덮어쓰기. 간단하면 `--full-refresh`.
- **Airflow ↔ dbt**: Airflow는 prod 오케스트레이터(스케줄·날짜 루프·동시성), dbt는 변환 실행. 연동 = Airflow의 logical date(`ds`)를 dbt `--vars`로 주입.
  - 대규모 backfill = "하루×365 순차"가 아니라 "월 chunk × 병렬". 전용 자원·비용 주의.
- **환경 분리**: dev(사람이 수동 `dbt run --target dev`, 내 dev 스키마) / CI(PR 트리거 자동) / prod(Airflow). **dev엔 Airflow 안 씀** — backfill *로직*은 dev에서 수동 dbt로 테스트 가능, *오케스트레이션*만 Airflow 층.
- **DE/AE 경계**: DE=적재·인프라·Airflow / AE=dbt 변환·모델·테스트. backfill은 협업 지점(AE=로직, DE=실행), 성숙한 조직은 AE 셀프서브.
- **검증 정석**: prod 안 건드리고 **dev 스키마에 빌드 → 노트북/Impala로 쿼리 + `dbt test` + prod와 diff(`audit_helper`)**.

---

## 6. Claude로 다시 작업할 때 참고 메모

- 이 파일(WORKLOG.md)을 먼저 보여주면 맥락 파악 빠름.
- 환경: Windows + PowerShell, Python은 **3.12**(venv, uv 관리), dbt-duckdb.
- 새 PC면 위 "0. 환경 재현"부터. `dbt build`로 PASS 확인 후 작업 시작.
- 한글 주석 파일 다룰 때 `PYTHONUTF8=1` 필수.
- 작업 방식 선호: git 단계(commit/push/merge)는 직접 실행, 파일 셋업/변환은 Claude가 대행.
