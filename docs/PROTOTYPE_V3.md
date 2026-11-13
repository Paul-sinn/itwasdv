# 시제품 v3 지시서: 경제 뼈대

> 2026-11-13. 사용자가 자리를 비운 동안 조율자가 **추천안으로 정함** (물어볼 것은 바깥 폴더 `QUESTIONS.md`에 모음).
> v2 튜닝 플레이 테스트는 건너뜀 (기획서 16.8). 숫자는 `data/balance.json`의 `trip`, `engine`, `offline` 묶음.
> 기획서: `docs/GAME_PLAN.md` 16.1, 16.2, 16.7, 16.9, 15.4, 15.5

## 이 시제품으로 알아낼 것 (딱 하나)

**돈 계산을 "속도 기반 한 바퀴"로 통째로 바꿔도, 띠에서 트럭이 돌고 돈이 쌓이고 강화를 누르는 흐름이 지금처럼 자연스럽게 도나?**

## 정한 것

| 항목 | 정한 것 |
|---|---|
| 순서 | 계산 담당이 core를 **새 약속으로 바로 갈아엎는다** (옛 함수와 같이 두지 않음). 그동안 화면 담당은 core와 상관없는 일(번역 파일, 돈 표기, +N 표기)을 한다. 계산이 끝나면 화면 담당이 합쳐서 새 약속으로 옮긴다. 껍데기 함수는 안 만든다 |
| v2 튜닝 8칸 | **v3에서 지운다** (기획서 16.3 "지우고 새로"). 효과가 옛 수입 식에 매달려 있어서 남기면 새 식에 다시 붙이는 헛일이 생김. 세팅 돌리기는 v4 |
| 트럭 여러 대 | 데이터 구조만. 새 게임은 트럭 1대(번호 0). 사는 화면·고르는 탭은 v7 |
| 고장 상태 | 없앤다. 퍼지면 스페어 1개를 자동으로 쓰고 +15로. 트럭은 안 멈춤 |
| 스페어 엔진 | 들고 있는 개수(`spares`)가 생김. 차고에서 언제든 고정가로 삼 (카센터 화면은 v6). 배송 1건마다 낮은 확률로 +1, 꺼둔 동안은 평균값 |
| +18 이상 강화 | 퍼질 수 있는 단계(`destroy[단계] > 0`)는 스페어 1개 이상 있어야 누름. 보험은 v6 |
| 실패 | 단계 유지 (지금 코드 그대로) |
| 이미 json에 있는 숫자 | `engine.success`, `engine.destroy`, `engine.broken_drop_to`, `engine.spare_price`, 꺼둔 동안 8시간·50%는 **json 값 그대로** (시트와 다르지만 기획서 규칙상 json이 기준 → `QUESTIONS.md` Q1) |
| 아직 어디에도 없는 숫자 | 단가, 도로 길이, 싣는 시간, 정차 시간, 기본 적재량, 기름값·정비비 %, 강화 비용 기본값·배수, 스페어 드랍 확률은 시트에도 없음 ("시뮬레이터로"). 아래 "임시 시작값"으로 넣고 밸런스 담당이 제안 → 사용자 허락 뒤 확정 (`QUESTIONS.md` Q2) |
| 저장 | 형식 3. 형식 1·2 파일은 변환하지 않고 `save.v2.json`으로 이름만 바꿔 남긴 뒤 새 게임. 백업 3개 돌려 쓰기 + 깨지면 백업에서 자동 복구 |
| 돈 | 64비트 정수(`int`). 배송 1건 돈도 정수 |
| 화면 트럭 속도 | 돈과 분리. 강화 단계에 따라 빨라지다 상한(`feel.gd`)에서 멈춤. "+돈" 표시는 계산 쪽 배송 완료 이벤트에 맞춤. 속도선·잔상·배기 연기 키우기는 그림이 나온 뒤 (→ IDEAS) |
| 번역 | Godot 번역 CSV(`locale/strings.csv`, 열: keys, ko, en). 화면 글자는 `tr("KEY")`. 언어 고르는 설정은 v8, 지금은 OS 언어를 따름 (ko가 아니면 en) |
| 돈 표기 | ko: 1만 미만은 쉼표("9,999"), 그 위는 "1.2만", "3.4억", "1.2조". en: 1000 미만은 그대로, 그 위는 "12K", "340M", "1.2B", "3.4T". 단위로 나눈 값이 100 미만이면 소수 첫째 자리까지(버림, ".0"은 뗌), 100 이상이면 정수 |
| 강화 표기 | "+18" (★, "강" 없앰). 말로 쓸 때는 "단계" |
| 3분 미만 자리 비움 무시, 돌아왔을 때 요약 화면 | v5 |
| 24시간 켜두기 | 코드 없음. 있는 `tests/soak_desktop.ps1 -minutes 1440`을 사용자가 자리 비울 때 돌림 |

## 계산식

속도 단위: 출력 1 = 1초에 도로 1칸.

```
출력(단계)      = engine.base_power + power_gain[0] + … + power_gain[단계-1]
속도(트럭)      = 출력(트럭 단계)                      (v4에서 × (1 + 세팅 이동 속도 % 합))
적재량 N(트럭)  = trip.base_cargo                      (v4에서 적재함 세팅)
한 바퀴 초      = trip.load_seconds + trip.road_length ÷ 속도 + N × trip.stop_seconds
배송 1건 돈     = unit_price − round(unit_price × fuel_rate) − round(unit_price × maint_rate)   (정수)
한 바퀴 수입    = N × 배송 1건 돈
시간당 수입     = 한 바퀴 수입 × 3600 ÷ 한 바퀴 초      (소수. 화면에는 버림)
i번째 집(1~N) 배송 완료 시각 (한 바퀴 안) = load_seconds + (road_length ÷ 속도) × i ÷ (N+1) + i × stop_seconds
강화 비용(단계) = round(engine.cost_base × engine.cost_mult ^ 단계)   (정수)
스페어 드랍     = 배송 1건마다 engine.spare_drop_chance 확률로 스페어 +1
꺼둔 동안       : 시간 = min(꺼둔 초 ÷ 3600, offline.cap_hours),  꺼둔 초 ≤ 0 이면 전부 0
                  돈   = floor(시간당 수입 × 시간 × offline.rate)   (트럭마다 더함)
                  배송 = floor(N × 3600 ÷ 한 바퀴 초 × 시간 × offline.rate)
                  스페어 = 배송 × spare_drop_chance 를 spare_drop_carry(소수)에 더하고, 정수 부분만큼 스페어 +, 나머지는 남김
강화            : 성공 → 단계 +1 / 실패 → 그대로 / 퍼짐 → 스페어 −1, 단계 = min(단계, broken_drop_to)
```

시뮬(`tools/tune_sim.py`)도 이 식을 그대로 쓴다.

## 옮길 숫자

시트에서 옮기는 것 (시작값. 옮긴 뒤로는 json에서만 고침):

| 시트 탭 | 칸 | 값 | balance.json 키 |
|---|---|---|---|
| 강화 단계 | B1 | 100 | `engine.base_power` |
| 강화 단계 | E4:E33 | 5×10개, 10×5개, 20×5개, 35×5개, 60×5개 (순서대로 30개) | `engine.power_gain` |

임시 시작값 (시트에 없음. 밸런스 담당이 바꿀 수 있음):

| balance.json 키 | 값 | 뜻 |
|---|---|---|
| `trip.unit_price` | 100 | 배송 1건 단가 (원) |
| `trip.base_cargo` | 5 | 한 바퀴에 싣는 개수 |
| `trip.road_length` | 12000 | 한 바퀴 도로 길이 (칸) |
| `trip.load_seconds` | 10 | 싣는 시간 |
| `trip.stop_seconds` | 2 | 집 앞 정차 시간 |
| `trip.fuel_rate` | 0.10 | 기름값 (단가의 %) |
| `trip.maint_rate` | 0.05 | 정비비 (단가의 %) |
| `engine.cost_base` | 350 | 강화 비용 기본값 |
| `engine.cost_mult` | 1.5 | 단계마다 곱하는 수 |
| `engine.spare_drop_chance` | 0.0002 | 배송 1건마다 스페어 드랍 확률 |

이 값이면 +0 시간당 약 1만 900원(한 바퀴 140초), +18 약 2만 3천 원.

json 모양 바꾸기 (값은 그대로): `income.offline_cap_hours` → `offline.cap_hours`, `income.offline_rate` → `offline.rate`.
지우는 묶음: `income`(나머지), `engine.cost_hours`, `tune`, `company`, `sources`. `version`은 "0.6".

## 코드 약속 (계산 담당 ↔ 화면 담당)

`scripts/core/truck_state.gd` (새 파일, `extends RefCounted`) — 트럭 1대
```gdscript
var star: int = 0              ## 강화 단계 0~max_star
var lap_clock: float = 0.0     ## 지금 바퀴에서 흐른 초
var lap_delivered: int = 0     ## 지금 바퀴에서 배송 끝낸 집 수
var success_count: int = 0
var fail_count: int = 0
var destroy_count: int = 0
```

`scripts/core/game_state.gd`
```gdscript
var money: int = 0
var spares: int = 0                  ## 들고 있는 스페어 엔진
var spare_drop_carry: float = 0.0    ## 꺼둔 동안 스페어 평균값의 소수 나머지
var trucks: Array = []               ## TruckState들. 새 게임은 1대
static func new_game() -> GameState  ## 트럭 1대짜리 새 상태
func truck(i: int) -> TruckState
func can_buy_spare(b) -> bool        ## 돈 >= 스페어 가격 (언제든)
func buy_spare(b) -> bool            ## 돈 빼고 spares +1
```

`scripts/core/trip.gd` (새 파일. **스페어 드랍 굴리기 전용 파일**)
```gdscript
static func power(b, star: int) -> int
static func speed(b, t: TruckState) -> float
static func cargo(b, t: TruckState) -> int
static func lap_seconds(b, t: TruckState) -> float
static func parcel_pay(b) -> int
static func lap_income(b, t: TruckState) -> int
static func hourly_income(b, t: TruckState) -> float
static func hourly_income_at(b, t: TruckState, star: int) -> float   ## 단계만 바꿔서 ("성공하면 시간당")
## 트럭 i를 dt초 진행. 그사이 끝난 배송마다 돈을 더하고 이벤트를 돌려준다 (dt가 길면 여러 바퀴).
##   { "type": "parcel", "pay": int, "house": int(0~N-1) } / { "type": "spare" }
static func advance(state: GameState, b, i: int, dt: float, rng: RandomNumberGenerator) -> Array
## 꺼둔 동안을 상태에 반영(모든 트럭)하고 { "money": int, "parcels": int, "spares": int, "hours": float } 를 돌려준다
static func apply_offline(state: GameState, b, seconds_away: float) -> Dictionary
```

`scripts/core/economy.gd`
```gdscript
static func enhance_cost(b, star: int) -> int
static func spare_price(b) -> int
static func seconds_to_afford(price: int, money: int, hourly: float) -> float   ## 지금과 같은 뜻
```

`scripts/core/enhance.gd` (강화 굴리기 전용. `random01`, `chances`, `decide_chances`, `decide`, `roll`은 그대로)
```gdscript
enum Result { BLOCKED = -1, SUCCESS, FAIL, DESTROY }
enum Block { NONE, MAX_STAR, NO_MONEY, NO_SPARE }
static func needs_spare(b, star: int) -> bool                          ## destroy[star] > 0
static func block_reason(state, b, i: int) -> Block                    ## 트럭 i
static func try_enhance(state, b, i: int, rng) -> Result               ## 퍼지면 스페어 자동 사용
static func force_destroy(state, b, i: int) -> void                    ## 치트용: 스페어가 있으면 −1, 단계 내림
```

`scripts/core/save.gd`
```gdscript
const FORMAT_VERSION := 3
enum Status { OK, NONE, BROKEN }
static func write_file(path, state, saved_at_unix: int) -> Error       ## 임시 파일 → 이름 바꾸기. 쓰기 전에 지금 파일을 백업으로 돌림
static func read_file(path, b) -> Dictionary
##   { status, state, saved_at, error, recovered: bool, old_kept: String }
##   recovered = 본 파일이 깨져서 백업에서 살림 (status는 OK).  old_kept = 옛 형식 파일을 옮겨 둔 경로 (없으면 "")
static func delete_file(path) -> void                                  ## 백업까지 지움 (치트 F3)
```
- 백업 이름: `path + ".bak1"`(가장 최근) ~ `".bak3"`. 본 파일이 깨졌으면 `.broken`으로 옮기고 bak1 → bak2 → bak3 순서로 읽히는 첫 파일을 씀. 전부 안 되면 BROKEN(새 게임)
- 형식 1·2 파일: `save.v2.json`(같은 폴더)으로 이름 바꾸고 status NONE, `old_kept`에 그 경로
- 저장 내용: `version`, `saved_at_utc`, `money`, `spares`, `spare_drop_carry`, `trucks: [ { star, lap_clock, lap_delivered, success_count, fail_count, destroy_count } ]`. 모르는 키는 버리고 범위 밖 값은 자름(음수 돈·스페어는 BROKEN)
- 시각이 드는 함수는 지금처럼 지금 시각을 인자로 받는다

`scripts/ui/fmt.gd` (화면 담당)
```gdscript
static func money(v: int) -> String      ## 위 "돈 표기". 지금 언어(TranslationServer)에 따라 만/억 또는 K/M
```

## 범위

**만드는 것:** 위 "정한 것" 전부, 새 식에 맞춘 `tools/tune_sim.py` (판정: 30일째 지금 단계 중앙값, 가볍게 2.5시간 / 열심히 8시간, 나머지는 꺼둠), `tools/delivery_sim.py` 삭제.

**안 만드는 것 (→ IDEAS.md나 뒤 시제품):** 세팅 돌리기(v4), 보험·명장(v6), 카센터·건물 클릭(v6), 보조 트럭 사기·고르는 탭(v7), 세금(v7), 언어 설정(v8), 창고·야간 배송팀 업그레이드(v5), 3분 미만 무시·요약 화면(v5), 속도선·잔상 연출, 출력 제한 배송(v6~v7).

## 작업 순서와 담당

계산 = `core-dev`, 폴더 `itwasdv-window`, 가지 `v3-core`. 화면 = `ui-dev`, 폴더 `itwasdv-town`, 가지 `v3-ui`.

| 단계 | 담당 | 고치는 파일 | 안 건드리는 파일 | 완료 기준 |
|---|---|---|---|---|
| C1 한 바퀴 계산·강화·스페어 | 계산 | `data/balance.json`, `scripts/core/*`(`save.gd`는 돌아가게만), `tests/test_*.gd`, `tests/run_tests.gd` / 삭제: `scripts/core/tune.gd`, `tests/test_tune.gd` | `scripts/ui/`, `scenes/`, `tests/check_*`, `locale/` | `run_tests` 전부 통과(종료 코드 0). 새 테스트: ① +0/+10/+18/+30의 출력·한 바퀴 초·시간당 수입이 위 식과 같음(값을 한 줄씩 찍음) ② `advance`로 3600초 돌린 돈이 시간당 수입과 한 바퀴 수입 1번치 안쪽 ③ `advance`를 0.1초씩 나눠 돌려도 한 번에 돌린 것과 돈·배송 수가 같음 ④ 스페어 드랍 seed 고정 10만 건, 확률을 0.05로 바꾼 balance로 1%p 안쪽 ⑤ 퍼지는 단계에서 스페어 0이면 `NO_SPARE`, 퍼지면 스페어 −1·단계 15·통계 +1 ⑥ 강화 비용이 식과 같고 정수 ⑦ 꺼둔 동안: 0초 이하 0, 상한 넘으면 상한까지, 스페어 소수 나머지가 이어짐 ⑧ balance 검사: `power_gain` 길이 30, 음수 없음, 비율 0~1, `cost_mult` > 1 |
| C2 저장 | 계산 | `scripts/core/save.gd`, `tests/test_save.gd` | 위와 같음 | `run_tests` 통과. 새 테스트: 형식 3 쓰고 읽기, 형식 2 파일 → `save.v2.json`으로 남고 NONE, 4번 저장하면 bak1~3이 최근 3개, 본 파일을 깨뜨리면 bak1에서 복구(`recovered`), 전부 깨지면 BROKEN, 돈이 9e15 넘어도 정확히 왕복 |
| C3 시뮬 | 계산 | `tools/tune_sim.py` / 삭제: `tools/delivery_sim.py` | 위와 같음 | `python -I -X utf8 tools/tune_sim.py --players 200 --seed 1` 이 가볍게·열심히의 30일째 지금 단계 중앙값·하위 10%, 퍼짐 횟수 평균을 찍음. `--table` 이 +0/+10/+18/+30 시간당 수입을 찍고 C1 테스트가 찍은 값과 같음 |
| U1 번역·표기 (C1~C2와 동시에) | 화면 | `locale/strings.csv`, `project.godot`(번역 등록만), `scripts/ui/*`(튜닝 두 파일 빼고), `tests/test_fmt.gd`, 새 `tests/check_i18n.gd` | `scripts/core/`, `data/`, `tools/`, `scripts/ui/tune_tab.gd`·`tune_text.gd`(U2에서 지움) | "기존 확인" 전부 통과. `check_i18n.gd`: ko·en 각각 코드가 쓰는 모든 키가 번역됨(키 그대로 나오면 실패), `scripts/ui/`(튜닝 두 파일 제외)에 한글 화면 글자가 코드에 직접 안 남음, `Fmt.money` 예시 (9999, 12000, 123456789, 340000000, 1200000000000)가 ko·en 표기 규칙대로. ★와 "강" 표기가 "+N"으로 |
| U2 새 약속으로 옮기기 (C2 뒤, `v3-core` 합치고) | 화면 | `scripts/ui/*`, `scenes/`, `tests/check_*.gd`, `locale/strings.csv` / 삭제: `tune_tab.gd`, `tune_text.gd`, `tests/check_tune.gd` | `scripts/core/`, `data/`, `tools/`, `tests/test_*`(`test_fmt` 빼고) | "기존 확인" 전부 통과 + 확인 줄: ① `check_town_hour`: 1시간 돌린 돈이 `Trip.hourly_income`과 한 바퀴치 안쪽(+0/+10/+20/+30), "+돈" 표시 수 = 배송 이벤트 수 ② `check_garage`: 비용이 `Economy.enhance_cost`와 같음, +18에서 스페어 0이면 버튼 꺼짐 + 이유 글, 스페어 사면 켜짐, 퍼지면 스페어 −1·+15·트럭 계속 달림, 스페어 개수 표시 ③ `check_save`: 꺼둔 동안 돈·스페어 표시, 옛 형식 파일 안내, 백업 복구 안내 ④ 화면 트럭 속도가 +30에서도 `feel.gd` 상한을 안 넘음 ⑤ en 언어로도 차고가 뜨고 키가 그대로 안 보임 |

## 플레이 테스트 (사용자가 직접)

20분쯤 켜 두고 강화를 +8 근처까지. "아니오"가 2개 이상이면 다음 기능보다 숫자·연출부터.

1. 트럭이 집마다 서고 "+돈"이 뜨는 박자가 자연스러운가?
2. 강화를 올렸을 때 "빨라졌다 / 더 번다"가 느껴지는가?
3. 강화 비용이 "조금 모으면 누를 수 있는" 정도인가? (너무 싸거나 너무 멀지 않은가)
4. 돈 표기(1.2만)가 한눈에 읽히는가?
5. v2 때와 비교해 어색해지거나 없어져서 아쉬운 것이 없는가?
