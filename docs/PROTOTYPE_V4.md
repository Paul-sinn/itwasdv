# 시제품 v4 지시서: 세팅 돌리기 (적재함·ECU)

> 2026-11-13. 사용자가 자리를 비운 동안 조율자가 **추천안으로 정함** (물어볼 것은 바깥 폴더 `QUESTIONS.md` Q5~).
> v3 플레이 테스트는 사용자가 돌아온 뒤에 (건너뛴 것이 아니라 미룸. 결과가 나쁘면 v3 숫자·연출부터 다시).
> 숫자는 `data/balance.json`의 `setting` 묶음. 기획서: `docs/GAME_PLAN.md` 4.5, 16.2, 16.3, 16.4

## 이 시제품으로 알아낼 것 (딱 하나)

**세팅 돌리기 한 번 한 번이 "한 번만 더"가 되나?** (돌리기 → 예전 것 / 새 것 고르기 → 천장 숫자가 오르는 것이 기다려지는가)

## 정한 것

| 항목 | 정한 것 |
|---|---|
| 순서 | v3와 같다. 계산 담당이 C1을 끝내면 화면 담당이 합쳐서 U1을 하고, 그동안 계산 담당은 C2(시뮬). 껍데기 함수 없음 |
| 부품 | 적재함(처음부터), ECU(그 트럭 엔진 +5 이상). 타이어·터보는 v7. 부품·옵션은 json 목록이라 나중에 json만 더하면 되게 |
| 처음 상태 | 등급 순정, 줄 없음 (한 번도 안 돌림) |
| 돌리기 1번 | ① 비용을 냄 ② 그 부품·그 등급의 천장 카운터 +1 ③ 등급업 굴림 (카운터가 천장 숫자에 닿으면 무조건 등급업) ④ 등급업이면 그 카운터를 0으로 ⑤ 새 등급의 줄 수만큼 옵션을 뽑아 "새 상태"를 만듦 ⑥ 예전 상태 / 새 상태 중 고름 |
| 고르기 (메모리얼) | 등급 + 줄을 통째로 고른다. 등급업이 떠도 예전 것을 고르면 등급도 예전 등급 (카운터는 이미 0). 고르기 전에는 그 부품을 다시 못 돌림. 고르지 않고 꺼도 저장돼 있어 다음에 고름 |
| 줄 | 줄마다 따로 뽑는다(같은 옵션이 여러 줄에 나올 수 있음). 수치는 그 상태의 등급 수치. 등급 수치가 0인 옵션(엔진 보호의 순정·스트리트)은 그 등급에서 안 뽑힘 |
| 옵션이 뽑힐 확률 | 시트에 없음 → 가중치를 임시 시작값으로 (아래). 화면에 확률을 보여 줌 |
| 돌리기 비용 | 시트 "미정" → 등급별 고정 금액을 임시 시작값으로 |
| 이동 속도 | 속도 = 출력 × (1 + 이동 속도 % 합). 그 트럭의 모든 부품 줄을 더함 |
| 적재량 | N = floor(기본 적재량 × (1 + 적재량 % 합)) |
| 기름값 절감 | 기름값 = round(단가 × fuel_rate × (1 − 절감)). 절감 합(기름값 + 정비비)은 `cost_cut_cap` 0.6까지. v4에는 기름값 절감만 있음 |
| 엔진 보호 | 퍼짐 확률 × (1 − min(합, 0.3)). 줄어든 만큼은 실패(유지) |
| 오버부스트 | 한 바퀴를 출발할 때 (확률 합)으로 굴림. 걸리면 그 바퀴는 10초 동안 속도 2배 → 달리는 시간이 min(10, 달리는 시간 ÷ 2)초 줄어듦. 꺼둔 동안과 "시간당 수입" 표시는 평균값 |
| **v3 임시 숫자 고침** | 적재량 5% 한 줄이 실제로 1건이 되게, 그리고 기름값 2% 절감이 원 단위에서 사라지지 않게 돈 단위를 키움: 기본 적재량 5 → 20, 단가 100 → 2500, 정차 2초 → 0.5초, 강화 비용 기본값 350 → 35000, 스페어 가격 50000 → 5000000 (전부 ×100 또는 같은 비율이라 "몇 시간치"는 그대로. 한 바퀴 140초도 그대로). 덤으로 "+돈"이 22초가 아니라 6.5초마다 떠서 트럭이 집 앞에서 오래 서는 문제(Q4)가 줄어듦 |
| 저장 | 형식 4. 형식 3 파일은 읽힘 (세팅 없음으로) |
| 명장 1.5배, 외형 변경·외형 고정, 띠에 등급 표시 | v6 / 그림이 나온 뒤 (→ IDEAS) |

## 계산식

```
속도(트럭)   = 출력(단계) × (1 + total(speed))
N(트럭)      = floor(trip.base_cargo × (1 + total(cargo)))
절감         : f = total(fuel_cut), m = total(maint_cut)  (v4에서 m은 늘 0)
               f + m > cost_cut_cap 이면 둘 다 × cost_cut_cap ÷ (f + m)
배송 1건 돈  = unit_price − round(unit_price × fuel_rate × (1 − f)) − round(unit_price × maint_rate × (1 − m))
달리는 초    = road_length ÷ 속도.  오버부스트가 걸린 바퀴는 − min(overboost_seconds, 달리는 초 ÷ overboost_mult)
한 바퀴 초   = load_seconds + 달리는 초 + N × stop_seconds
평균 한 바퀴 초 = 안 걸린 바퀴 초 × (1 − p) + 걸린 바퀴 초 × p,   p = min(total(overboost), 1)
시간당 수입  = N × 배송 1건 돈 × 3600 ÷ 평균 한 바퀴 초        (꺼둔 동안도 이 값)
퍼짐 확률    = destroy[단계] × (1 − min(total(engine_guard), engine_guard_cap)),  실패 = 1 − 성공 − 퍼짐
total(옵션)  = 그 트럭의 모든 부품에서, 지금 쓰는 상태의 줄 중 그 옵션인 줄마다 values[그 부품 등급] 을 더함
등급업       = 카운터+1 뒤 카운터 ≥ ceiling[등급] 이면 무조건, 아니면 up_chance[등급] 확률. 최고 등급은 등급업 없음(카운터 안 셈)
옵션 뽑기    = 그 부품의 옵션 중 그 등급 수치가 0이 아닌 것(잡옵은 늘 포함)에서 weight 비율로
```

## 옮길 숫자

시트에서 옮기는 것 (시작값):

| 시트 탭 | 칸 | 값 | balance.json 키 |
|---|---|---|---|
| 세팅 규칙 | B2 | 1, 2, 3, 3, 3 | `setting.lines_by_grade` |
| 세팅 규칙 | B10, B11 | 0.6, 0.3 | `setting.cost_cut_cap`, `setting.engine_guard_cap` |
| 세팅 등급업 | B5:B8 | 0.3, 0.08, 0.02, 0.003 | `setting.up_chance` |
| 세팅 등급업 | C5:C8 | 5, 20, 80, 500 | `setting.ceiling` |
| 세팅 옵션 수치 | D2:H2 | 0.03, 0.05, 0.08, 0.13, 0.20 | `setting.options.speed.values` |
| 세팅 옵션 수치 | D3:H3 | 0.02, 0.04, 0.06, 0.09, 0.12 | `setting.options.fuel_cut.values` |
| 세팅 옵션 수치 | D4:H4 | 0.05, 0.08, 0.12, 0.20, 0.30 | `setting.options.cargo.values` |
| 세팅 옵션 수치 | D7:H7 | 0, 0, 0.04, 0.06, 0.10 | `setting.options.engine_guard.values` |
| 세팅 옵션 수치 | D8:H8 | 0.01, 0.02, 0.03, 0.05, 0.08 | `setting.options.overboost.values` |
| 세팅 옵션 수치 | A8 | 10초, 2배 | `setting.overboost_seconds`, `setting.overboost_mult` |

임시 시작값 (시트에 없음):

| balance.json 키 | 값 | 뜻 |
|---|---|---|
| `setting.roll_cost` | 20000, 80000, 400000, 2000000, 10000000 | 등급별 돌리기 1번 비용 (순정~프로토타입) |
| `setting.options.<id>.weight` | speed 6, fuel_cut 10, cargo 10, engine_guard 10, overboost 10, 잡옵 5개 각 12 | 뽑힐 가중치 |
| `setting.parts` | `cargo_box`: unlock_star 0, 옵션 speed·fuel_cut·cargo + 잡옵 5 / `ecu`: unlock_star 5, 옵션 speed·fuel_cut·engine_guard·overboost + 잡옵 5 | 부품 목록 |
| v3 숫자 고침 | `trip.base_cargo` 20, `trip.unit_price` 2500, `trip.stop_seconds` 0.5, `engine.cost_base` 35000, `engine.spare_price` 5000000 | 위 "정한 것" |

잡옵 id: `junk_ride`(승차감 향상), `junk_scent`(실내 방향제 향 개선), `junk_cupholder`(컵홀더 추가), `junk_radio`(라디오 수신 감도), `junk_gloss`(외관 광택). `values` 없음, `kind`는 "junk".
옵션의 `kind`: speed·fuel_cut = "common", cargo·engine_guard·overboost = "own". 등급 이름·옵션 이름·부품 이름은 json이 아니라 번역 파일에.

## 코드 약속 (계산 담당 ↔ 화면 담당)

`scripts/core/truck_state.gd`
```gdscript
var settings: Dictionary = {}   ## 부품 id → { "grade": int, "lines": Array(옵션 id), "counters": Array(등급별 int), "pending": null 또는 { "grade": int, "lines": Array } }
var boost_lap: bool = false     ## 지금 바퀴에 오버부스트가 걸렸나
func part(part_id: String) -> Dictionary   ## 없으면 처음 상태(순정, 줄 없음)를 만들어 돌려줌
```

`scripts/core/setting.gd` (새 파일. **등급업·옵션 뽑기 굴리기 전용 파일**. 오버부스트 굴리기는 `trip.gd`)
```gdscript
enum Block { NONE, LOCKED, NO_MONEY, PENDING }
static func part_ids(b) -> Array                                   ## json 순서 ["cargo_box", "ecu"]
static func max_grade(b) -> int                                    ## 4
static func unlocked(b, t: TruckState, part: String) -> bool
static func unlock_star(b, part: String) -> int
static func roll_cost(b, grade: int) -> int
static func up_chance(b, grade: int) -> float                      ## 최고 등급은 0
static func ceiling(b, grade: int) -> int                          ## 최고 등급은 0
static func line_count(b, grade: int) -> int
static func option_kind(b, option: String) -> String               ## "common" / "own" / "junk"
static func option_value(b, option: String, grade: int) -> float   ## 잡옵은 0
static func option_chances(b, part: String, grade: int) -> Dictionary   ## 옵션 id → 한 줄에 뽑힐 확률 (합 1)
static func total(b, t: TruckState, option: String) -> float       ## 그 트럭의 지금 쓰는 줄 합 (상한 적용 전)
static func block_reason(state, b, i: int, part: String) -> Block
## 돌리기 1번. 못 돌리면 { "ok": false }. 돌렸으면 { "ok": true, "grade_up": bool, "pity": bool } 이고 part.pending에 새 상태가 들어감
static func try_roll(state, b, i: int, part: String, rng) -> Dictionary
static func choose(state, i: int, part: String, take_new: bool) -> void   ## pending을 받거나 버림. pending이 없으면 아무 일 없음
```

`scripts/core/trip.gd` (바뀌는 것)
```gdscript
static func parcel_pay(b, t: TruckState) -> int        ## 인자에 트럭이 붙음 (기름값 절감)
static func lap_seconds(b, t: TruckState) -> float     ## 지금 바퀴 (boost_lap 반영)
static func avg_lap_seconds(b, t: TruckState) -> float ## 오버부스트 평균
## hourly_income / hourly_income_at / apply_offline 은 평균 한 바퀴 초를 씀. advance 이벤트에 { "type": "boost" } (그 바퀴 출발 때 걸림) 추가
```

`scripts/core/enhance.gd`
```gdscript
static func chances_for(b, t: TruckState) -> Dictionary   ## 엔진 보호를 반영한 { success, fail, destroy }. try_enhance도 이걸로 굴림
```

`scripts/core/save.gd`: `FORMAT_VERSION := 4`. 트럭마다 `settings`(위 모양 그대로)와 `boost_lap`. 형식 3 파일은 세팅 없음으로 읽음(옮겨 두지 않음). 모르는 부품·옵션 id는 버리고, 등급·카운터는 범위로 자르고, 줄 수가 그 등급 줄 수보다 많으면 앞에서부터 자름.

## 범위

**만드는 것:** 위 전부 + 차고의 [세팅] 탭 + 시뮬에 세팅 넣기.
**안 만드는 것:** 타이어·터보(v7), 명장 보너스(v6), 외형 변경·외형 고정·띠의 등급 표시(그림 뒤), 잡옵 도감(v8), 줄 잠금(기획서: 없음).

## 작업 순서와 담당

계산 = `core-dev`, 폴더 `itwasdv-window`, 가지 `v4-core`. 화면 = `ui-dev`, 폴더 `itwasdv-town`, 가지 `v4-ui`.

| 단계 | 담당 | 고치는 파일 | 안 건드리는 파일 | 완료 기준 |
|---|---|---|---|---|
| C1 세팅 계산 | 계산 | `data/balance.json`, `scripts/core/*`, `tests/test_*.gd`(`test_fmt` 빼고), `tests/run_tests.gd` | `scripts/ui/`, `scenes/`, `tests/check_*`, `locale/`, `tools/` | `run_tests` 전부 통과(종료 코드 0). 새 테스트: ① json 값이 "옮길 숫자" 표와 같음(값을 찍음) ② 등급별 등급업: seed 고정 10만 번, 천장 없이 굴린 비율이 `up_chance`와 1%p 안쪽(프로토타입 전 단계는 0.3%라 0.1%p 안쪽) ③ 천장: 확률 0으로 바꾼 balance에서 정확히 `ceiling`번째에 등급업 + `pity` true, 카운터 0 ④ 평균 횟수: 순정→스트리트 10만 번 평균이 2.77 ± 0.05 ⑤ 옵션 뽑기 10만 줄이 `option_chances`와 1%p 안쪽, 순정·스트리트 ECU에서 engine_guard가 0번 ⑥ 줄 수 1/2/3/3/3 ⑦ 고르기: 등급업 뒤 예전 것을 고르면 등급·줄이 그대로이고 카운터는 0, 새 것을 고르면 바뀜, pending 중에는 `PENDING` ⑧ ECU는 +4에서 `LOCKED`, +5에서 열림 ⑨ 효과: speed 줄 → 속도·한 바퀴 초, cargo 5% 한 줄 → N 21, fuel_cut → 배송 1건 돈, 절감 상한 0.6, engine_guard 3줄(프로토타입) → 퍼짐 × 0.7, 오버부스트 걸린 바퀴 초와 평균 한 바퀴 초가 식과 같음 ⑩ `advance` 1시간 돈이 `hourly_income`(평균)과 2% 안쪽(오버부스트 24%, seed 고정) ⑪ 저장: 형식 4 왕복(pending 포함), 형식 3 파일 읽힘, 이상한 값 자름 ⑫ +0/+10/+18/+30 시간당 수입 표를 다시 찍음(v3의 100배) |
| C2 시뮬 | 계산 | `tools/tune_sim.py` | 위와 같음 (`tools/`만 고침) | `--table` 값이 C1 ⑫와 같음. 가상 유저가 세팅도 돌림(규칙은 파일 맨 위에 적음. 새 상태가 시간당 수입을 올리면 새 것을 고름). 결과에 30일·90일째 부품별 등급 분포, 세팅에 쓴 돈 비율, 30일째 지금 단계 중앙값을 찍음. `--no-setting`이면 세팅 없이 (v3와 비교용) |
| U1 세팅 탭 (C1 뒤, `v4-core` 합치고) | 화면 | `scripts/ui/*`, `scenes/`, `tests/check_*.gd`, `locale/*`, `tests/test_fmt.gd` | `scripts/core/`, `data/`, `tools/`, `tests/test_*`(`test_fmt` 빼고) | "기존 확인" 전부 통과 + 새 `tests/check_setting.gd`가 진짜 클릭으로 결과 줄을 찍음: ① [세팅] 탭에 적재함·ECU, +4에서 ECU는 잠김 글("엔진 +5에 열림"), +5에서 열림 ② 돌리기 → 돈이 `roll_cost`만큼 줄고 예전 것 / 새 것 고르는 화면이 뜸, 고르기 전엔 돌리기 버튼 꺼짐 ③ 새 것 / 예전 것을 고르면 줄·등급 글자가 그대로 반영 ④ "천장 n/N" 숫자가 돌릴 때마다 오르고 등급업 뒤 새 등급 기준으로 바뀜 ⑤ 등급업 확률과 옵션별 확률이 화면에 보이고 `Setting.up_chance`·`option_chances`와 같음 ⑥ 돈이 모자라면 버튼 꺼짐 + 모자란 금액 ⑦ 고르는 화면에서 껐다 켜도(저장 → 읽기) 고르는 화면이 다시 뜸 ⑧ 돌린 직후·고른 직후 저장 ⑨ 차고 강화 탭의 퍼짐 확률이 `Enhance.chances_for`와 같고, 시간당 수입이 세팅 반영 값 ⑩ en에서도 탭이 뜨고 키·한글이 안 보임 ⑪ 잡옵 줄은 수치 없이 이름만, 회색 |

화면 글자: 등급 = 순정/스트리트/스포츠/레이싱/프로토타입, 기능 이름 = "세팅 돌리기", 버튼 = "돌리기". 메이플 용어·"리맵"·"큐브"·"잠재" 금지.

## 플레이 테스트 (사용자가 직접)

30분쯤. 적재함을 스포츠 근처까지. "아니오"가 2개 이상이면 다음 기능보다 숫자·연출부터.

1. 돌리기를 누르고 결과가 뜰 때 기대되는가?
2. 예전 것 / 새 것 고르기가 헷갈리지 않는가?
3. 천장 숫자가 "조금만 더"를 만드는가?
4. 잡옵(컵홀더 등)이 떴을 때 짜증보다 웃음이 나는가?
5. 강화에 쓸지 세팅에 쓸지 고민이 생기는가?
