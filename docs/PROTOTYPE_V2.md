# 시제품 v2 지시서: 튜닝 (큐브)

> 2026-11-12 확정. 사용자가 "남은 스텝 계속 진행"이라고 해서, 초안의 [정해야 함]은 전부 **추천안**으로 정했다.
> 바꾸고 싶으면 숫자는 `data/balance.json`의 `tune` 묶음만, 부위·방식은 이 문서부터 고친다.

## 이 시제품으로 알아낼 것 (딱 하나)

**"강화 말고 튜닝(큐브)으로도 시간당 수익을 올리는 게 재밌고, 돈을 강화에 쓸지 튜닝에 쓸지 고민되나?"**

v0 플레이 테스트 뒤 사용자 의견: "강화 말고도 시간당 수익을 올릴 방법이 다양했으면 좋겠다 → 큐브로 차 튜닝".
2026-11-10 사용자 요청: "RPG 장비칸(투구·상의·하의·망토·장갑·무기·보조무기·반지)처럼 튜닝 부위가 여러 개였으면".

## 정한 것 (추천안)

| 항목 | 정한 것 |
|---|---|
| 부위 | 트럭 8칸. 엔진은 지금처럼 강화(★), 나머지 **7칸은 튜닝** (아래 표) |
| 큐브 방식 | **A: 등급만 올리기.** 부위마다 일반 → 레어 → 에픽 → 전설. 굴려서 확률로 한 등급 오름, 실패하면 그대로 (안 내려감) |
| 비용 | **고정 금액** (강수와 상관없음): 일반→레어 100원 / 레어→에픽 1,500원 / 에픽→전설 20,000원. 7칸 모두 같음 |
| 등급업 확률 | 15% / 5% / 1.5% (7칸 모두 같음) |
| 등급 색 | 일반 회색 / 레어 파랑 / 에픽 보라 / 전설 금색 |
| 연출 | 강화보다 짧게: 뜸 0.3초, 등급업이면 번쩍 + 등급 글자 커짐, 실패는 조용히 "그대로" |

B(메이플 잠재능력처럼 옵션 줄 굴리기), C(등급 안에서 수치 랜덤)는 `docs/IDEAS.md`로 (v3 후보).

## 튜닝 부위 7칸

부위마다 시간당 수익을 올리는 "방법"이 다르다. 숫자는 등급 순서(일반 / 레어 / 에픽 / 전설)이고 전부 `balance.json`의 `tune`에 있다.

| 부위 (id) | RPG로 치면 | 뭐냐면 | 효과 | 일반 / 레어 / 에픽 / 전설 | json 이름 |
|---|---|---|---|---|---|
| 터보 (turbo) | 보조무기 | 엔진에 공기를 더 밀어 넣어 힘을 키우는 장치 | 시간당 수익 +% | +0 / +10 / +25 / +50% | `turbo_income_bonus` |
| 타이어 (tire) | 신발 | 바퀴 고무 | **대박 배송 확률**: 집에 들를 때 가끔 그 집 돈을 몇 배로 | 0 / 5 / 10 / 15% | `tire_jackpot_chance` |
| 짐칸 (cargo) | 상의 | 택배를 싣는 뒷부분 | **대박 배송 배수** (타이어와 짝: 치명타 확률·피해처럼) | ×2 / ×3 / ×4 / ×5 | `cargo_jackpot_mult` |
| 서스펜션 (suspension) | 하의 | 덜컹거림을 잡는 스프링(쇼바) | 퍼짐 확률을 이만큼 줄임 (줄어든 만큼은 "실패"로) | 0 / 10 / 20 / 30% | `suspension_destroy_cut` |
| 연료 탱크 (fuel_tank) | 망토 | 기름통 | 꺼둔 동안 최대 시간 + | +0 / +2 / +4 / +8시간 | `fuel_extra_hours` |
| 내비게이션 (navigation) | 투구 | 길 안내 기계 | 꺼둔 동안 수익 비율 + (50% → 80%) | +0 / +10 / +20 / +30%p | `navi_extra_rate` |
| 엔진오일 (engine_oil) | 반지 | 엔진 속 윤활유 | 강화 비용 −% (스페어값은 그대로) | 0 / 5 / 10 / 20% | `oil_cost_cut` |

- 짐칸은 타이어가 일반(대박 0%)이면 효과가 없다. 화면에 "타이어를 올려야 대박이 나와요"라고 알려 준다.
- 전설 타이어 + 전설 짐칸 = 평균 수익 +60% (15% × (5 − 1)). 전설 터보 = +50%. 비슷하게 맞춤.

## 계산식

```
엔진 수익       = Economy.hourly_income(강수)                          (지금 그대로)
보통 수익       = 엔진 수익 × (1 + 터보)                               고장이면 0
대박 평균       = 1 + 타이어 확률 × (짐칸 배수 − 1)
평균 시간당 수익 = 보통 수익 × 대박 평균                                화면의 "시간당", 모으는 데 걸리는 시간, 꺼둔 동안 수익에 씀
배송 1번 돈     = 보통 수익 ÷ 3600 × 그 배송에 걸린 초 × (대박이면 짐칸 배수)
강화 비용       = roundf(cost_hours[강수] × 엔진 수익 × (1 − 엔진오일))   ← 터보·대박은 안 들어감
강화 누를 수 있는 돈 = 강화 비용 + 스페어값(퍼질 수 있는 강수면)        ← 스페어값 50,000원은 그대로
퍼짐 확률       = destroy[강수] × (1 − 서스펜션). 성공 확률은 그대로, 줄어든 만큼 실패(유지)
꺼둔 동안 수익   = 평균 시간당 수익 × min(꺼둔 시간, 8 + 연료 탱크) × (0.5 + 내비)   고장이면 0
튜닝 1번 비용   = roundf(tune_cost_hours[등급] × base_hourly)            → 100 / 1,500 / 20,000원
```
- 엔진이 퍼져도 튜닝 등급은 그대로. 고장 중에도 튜닝은 된다 (이미 있는 돈으로)
- 강화 비용이 터보와 상관없으니 → 튜닝을 올리면 강화할 돈이 더 빨리 모인다. 이게 "튜닝할까 강화할까" 고민거리
- 평균으로 보면 한 부위 전설까지 약 136만 원 (일반→레어 약 667원, 레어→에픽 약 3만 원, 에픽→전설 약 133만 원)

## 코드 약속 (계산 담당 ↔ 화면 담당)

v1처럼 에이전트 둘이 나눠 만든다. **화면 코드는 아래 함수만 쓴다.** 이름·뜻을 바꾸려면 조정자(메인 세션)에게 먼저 말한다.

**`scripts/core/tune.gd` (Tune)**: 튜닝 굴리기와 대박 굴리기는 이 파일에만 (강화의 `enhance.gd`처럼)
```gdscript
const PARTS := ["turbo", "tire", "cargo", "suspension", "fuel_tank", "navigation", "engine_oil"]  # 화면 순서
enum Result { BLOCKED = -1, UP, SAME }
enum Block { NONE, MAX_GRADE, NO_MONEY }
static func max_grade(b) -> int                                  # 3 (전설)
static func grade_name(b, grade: int) -> String                  # "일반" …
static func cost(b, grade: int) -> float                          # 그 등급에서 1번 굴리는 비용 (원)
static func up_chance(b, grade: int) -> float
static func effect(b, part: String, grade: int) -> float          # json 숫자 그대로 (예: turbo 레어 → 0.1)
static func block_reason(state, b, part: String) -> Block
static func try_tune(state, b, part: String, rng) -> Result        # 돈 빼고, 굴리고, 등급·통계 반영
static func roll_jackpot(state, b, rng) -> bool                    # 배송 1번이 대박인가. 맞으면 jackpot_count += 1
```

**`scripts/core/game_state.gd` (GameState)**: 튜닝을 반영한 돈 계산은 여기로
```gdscript
var tune: Dictionary            # 부위 id → 등급 (0~3). 새 게임·예전 저장 = 전부 0 (일반)
var tune_press_count: int       # 튜닝 버튼 누른 횟수
var tune_up_count: int          # 그중 등급업
var jackpot_count: int          # 대박 배송 횟수
func grade(part: String) -> int
func best_grade() -> int                     # 7칸 중 가장 높은 등급 (작은 화면 색 점)
func set_grade(b, part: String, g: int)      # F6 치트·테스트용 (0~최고로 자름)
func steady_hourly(b) -> float               # 보통 수익 (대박 뺌). 고장이면 0
func current_hourly(b) -> float              # 평균 시간당 수익 (대박 평균 포함). 고장이면 0
func jackpot_chance(b) -> float
func jackpot_mult(b) -> float
func delivery_pay(b, seconds: float, jackpot: bool) -> float
func enhance_cost(b) -> float                # 엔진오일 반영 (최고 강수에서는 부르지 않음)
func enhance_need(b) -> float                # 강화 비용 + 남길 스페어값
func enhance_chances(b) -> Dictionary        # { success, fail, destroy } 서스펜션 반영
func offline_cap_hours(b) -> float
func offline_rate(b) -> float
func offline_earnings(b, seconds_away: float) -> float
```

**`scripts/core/enhance.gd`**: `block_reason`·`try_enhance`가 위 `enhance_need` / `enhance_cost` / `enhance_chances`를 쓴다 (굴리기는 여전히 이 파일에만).
`Economy.hourly_income` / `enhance_cost(b, star)` / `Enhance.chances(b, star)`는 "튜닝 없는 엔진만" 값으로 그대로 남긴다 (기존 테스트용).

**`scripts/core/save.gd`**: 저장 형식 2. `tune` + 통계 3개 저장. 형식 1 파일은 전부 일반·0으로 읽음. 모르는 부위 id는 버림, 등급은 0~3으로 자름.

## 범위

**만드는 것**
- 계산: 위 약속 전부 + `balance.gd`에서 `tune` 읽기·검사
- 큰 화면 차고에 [엔진 강화] / [튜닝] 두 칸 (탭). 처음엔 [엔진 강화]
- [튜닝] 칸: 7부위 목록 (이름, 등급 색 글자, 지금 효과) → 하나 고르면 자세히: 하는 일 한 줄, 지금 효과 → 다음 등급 효과,
  등급업 확률, 비용, 돈 모자라면 "약 N분 뒤 가능", [튜닝] 버튼, 결과 한 줄. 아래에 튜닝 통계 (누른 횟수, 등급업 횟수, 대박 횟수).
  전설이면 "최고 등급" + 버튼 숨김
- [엔진 강화] 칸: 시간당 수익·강화 비용·퍼짐 확률이 튜닝 반영 값으로. 엔진오일·서스펜션이 깎아 준 만큼 작게 표시 (예: "강화 비용 70,000원 (엔진오일 −10%)")
- 동네: 대박 배송이면 돈 글자 대신 "대박! ×3 +1,234원" (더 크게, 금색). 작은 화면에서도 보임
- 작은 화면: 트럭 옆에 가장 높은 튜닝 등급 색 점 하나 (전부 일반이면 없음)
- 꺼둔 동안 팝업 문구: 연료 탱크·내비 반영 값으로
- 치트 F6: 7부위 전부 등급 +1 (최고 등급까지)
- 튜닝 연출 (위 "연출")

**안 만드는 것** (`docs/IDEAS.md`에 있음)
옵션 줄 굴리기(B), 수치 랜덤(C), 튜닝 키트(택배 상자에서 공짜 튜닝), 튜닝 데이(매주 등급업 2배 등), 부캐 트럭, 회사, NPC, 그 밖의 돈 수급처, 부위별 트럭 그림 바꾸기

## 작업 순서와 담당

각 단계 끝나면 커밋. 조정자가 합치고(merge) 전부 다시 확인한다.

**1단계: 계산 코드** (window 에이전트, 가지 `v2-core`, 폴더 `itwasdv-window`)
- 고치는 파일: `scripts/core/*`, `tests/test_*.gd`, `tests/run_tests.gd`, `tools/` (시뮬). **`scripts/ui/`는 안 건드림**
- `balance.gd`: `tune` 읽기·검사 (등급 4개, 비용·확률 3개, 효과 목록 4개씩, 확률·비율 0~1, 짐칸 배수 ≥ 1,
  서스펜션·엔진오일 < 1, offline_rate + 내비 최고 ≤ 1, 목록은 등급이 오를수록 줄지 않음)
- `tune.gd`, `game_state.gd`, `enhance.gd`, `save.gd`: 위 약속대로. 서로 preload가 빙글 돌지 않게 (부위 효과 숫자는 Balance에서 꺼내기)
- 시뮬: `tools/tune_sim.py` (트럭 1대, 엔진 + 7부위, 돈을 "가장 이득인 곳"에 쓰는 플레이어).
  튜닝 있을 때 / 없을 때 15·18·20·22·25강까지 걸리는 시간, 튜닝에 쓴 돈 비율, 시간별 부위 등급을 출력
- 테스트: 등급마다 10만 번 굴려 확률 1%p 안쪽, 비용 정답 값, 부위 효과가 수익·비용·퍼짐·꺼둔 동안에 반영,
  엔진만 값은 그대로, 퍼져도 등급 유지, 고장 중 튜닝 가능·수익 0, 대박 확률 10만 번, 저장·읽기(형식 1 → 일반)
- 완료 기준: `run_tests.gd` 전부 통과 + 기존 `check_*` 전부 통과 (화면 코드는 안 바꿨으니 그대로 통과해야 함)

**2단계: 화면** (town 에이전트, 가지 `v2-ui`, 폴더 `itwasdv-town`)
- 고치는 파일: `scripts/ui/*`, `scenes/*`, `tests/check_*.gd` (새 `check_tune.gd`). **`scripts/core/`는 안 건드림**
- 1단계가 끝나기 전에는 약속된 함수 껍데기(`tune.gd` 등, 조정자가 넣어 둠)로 화면부터 만든다.
  window 에이전트가 끝났다고 하면 `git merge v2-core` 해서 진짜 값으로 확인
- 위 "만드는 것"의 화면 부분 전부 + F6
- 완료 기준: `check_tune.gd` 진짜 클릭으로 7부위 각각 일반 → 전설, 돈 부족·최고 등급 화면, 탭 오가기,
  기존 `check_garage` / `check_save` / `check_switch`(화면 없이) 전부 통과

**3단계: 연출 + 동네 1시간 수익** (town 에이전트, 2단계 이어서)
- 튜닝 연출, 대박 글자
- 완료 기준 (`check_town_hour`에 더함):
  - 대박 없음(타이어 일반) + 터보 등급마다: 1시간 수익이 "엔진 수익 × (1 + 터보)"와 1% 안쪽
  - 대박 있음(타이어·짐칸 전설, 난수 seed 고정, 10시간): 평균이 "평균 시간당 수익"과 5% 안쪽

**보이는 창 확인**(전체 화면 깜빡임 등)은 사용자에게 먼저 물어본다. 화면 없는 확인으로 먼저 끝낸다.

## 플레이 테스트 (사용자가 직접)

30분 플레이 + F4로 18강, F6 없이 튜닝 직접 굴려 보기.

1. 튜닝 버튼 누를 때 강화와 다른 재미가 있나?
2. 돈을 강화에 쓸지 튜닝에 쓸지 고민되나?
3. 에픽 → 전설 1.5%를 계속 굴려 보고 싶나?
4. 부위마다 효과가 달라서 "어디부터 올릴까" 고민되나? 대박 배송이 동네에서 눈에 띄나?
5. 강화만 있을 때보다 더 오래 켜 두고 싶나?

"아니오"가 2개 이상이면 기능을 더 붙이지 말고 숫자(`tune` 묶음)와 연출부터 고친다.
