# 작업 로그 & 셋업 가이드 (dbt + git 실습)

> 이 repo는 **git(clone/commit/push/merge) + dbt 실습용**이다.
> 별도 DB 서버 없이 **DuckDB**로 `dbt build`(seed→run→test)가 로컬에서 바로 돌아간다.
> 다른 랩탑에서 `git pull` 후 아래 "환경 재현"만 따라하면 똑같이 동작한다.

---

## 진행 상황 (이어서 할 때 여기부터)

- ✅ 1일차: 환경 구축(uv+Py3.12, dbt-duckdb) → 프로젝트 DuckDB 변환 → git+dbt PR 흐름(브랜치→commit→push→PR→merge) → DuckDB 직접 쿼리 → docs/lineage → 문서화(WORKLOG, DBT_MODELING_MAP)
- ✅ 2일차: **Snapshots(SCD2)** 실습 완료 — `snapshots/customers_snapshot.sql`(check 전략, country 추적). `dbt snapshot`으로 초기 기록 → seed 변경 → 재snapshot으로 이력(valid_from/valid_to) 쌓이는 것 확인.
- ✅ 3일차: **dbt_utils 패키지** — `packages.yml`+`dbt deps`로 설치(1.4.0). `generate_surrogate_key`로 fct_orders_daily에 `order_region_key` 대리키 추가(CTE로 감싸서), `unique_combination_of_columns` 테스트 추가, `star`로 `orders_public`(order_amount 제외) 모델 생성. full-refresh로 incremental 재빌드.
- ⬜ **다음**: `DBT_MODELING_MAP.md` TODO → **① model contract**(타입 강제) → ② semantic layer/metric
- 🧹 정리할 것: `seeds/customers.csv`가 snapshot 실습 때 1번 US로 바뀐 채 커밋 안 됨 (필요시 되돌리거나 커밋)

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
