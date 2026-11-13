# 시제품 v5 지시서: 기사 레벨·퀘스트·창고·야간 배송팀·돌아왔을 때 요약

> 2026-11-13. 사용자가 자리를 비운 동안 조율자가 **추천안으로 정함** (물어볼 것은 바깥 폴더 `QUESTIONS.md` Q11~).
> v3·v4 플레이 테스트는 사용자가 돌아온 뒤에 (미룸).
> **기사 능력치 5개와 초기화는 이 지시서에 없다.** 숫자 시트 "기사 능력치" 탭을 읽어야 하는데 시트 연결이 끊겨서 못 읽었다. 포인트를 **받는 것까지만** 만들고, 쓰는 화면은 시트가 읽히면 v5b로 만든다.
> 숫자는 `data/balance.json`의 `driver`, `depot`, `quests` 묶음. 기획서: `docs/GAME_PLAN.md` 4.8, 4.9, 15.6, 15.9, 16.5

## 이 시제품으로 알아낼 것 (딱 하나)

**"다음 할 일"이 늘 하나 보이면 처음 1~2시간이 심심하지 않은가?** (퀘스트 → 보상 → 레벨업 → 다음 퀘스트가 끊기지 않는가)

## 정한 것

| 항목 | 정한 것 |
|---|---|
| 순서 | v3·v4와 같다. 계산 C1 → 화면이 합쳐서 U1, 그동안 계산은 C2(시뮬). 껍데기 없음 |
| 경험치 | 켜 둔 동안 배송 1건마다. 꺼둔 동안은 0 (노하우는 v5b). 퀘스트 보상, 강화 단계 첫 달성 보너스(한 번씩) |
| 레벨 | 1에서 시작, 만렙 50. 다음 레벨까지 = round(base_xp × 지금 레벨 ^ exponent) (시트 식: 레벨 2가 되는 데 100) |
| 포인트 | 레벨이 오를 때마다 1, 오른 레벨이 10의 배수면 +2 더. v5에서는 쌓이기만 함(`ability_points`) |
| 만렙 뒤 | 경험치는 회사 평판(`reputation`)으로 쌓임. 쓰는 곳은 v7 |
| 퀘스트 | 순서가 정해진 목록. 지금 차례인 것 하나만 보이고, 조건이 차면 **자동으로** 끝나며 보상(경험치 + 돈)을 줌. 이미 조건을 넘긴 퀘스트는 차례가 오면 바로 끝남(한 번 확인에 하나씩 → 알림이 하나씩 뜸). v5 목록은 지금 있는 기능만으로 22개 |
| 창고 확장 | 꺼둔 동안 쌓이는 시간. Lv1 4시간 → Lv2 6 → Lv3 8 → Lv4 12시간(대리점부터라 v5에서는 못 삼, "대리점부터" 글). **시작이 8시간에서 4시간으로 바뀐다** (기획서 결정 로그 [확정] "창고 확장(쌓이는 시간 4→12시간)". QUESTIONS Q1의 일부를 이걸로 정함) |
| 야간 배송팀 | 꺼둔 동안 버는 속도. Lv1 50% → 60 → 70 → Lv4 80% |
| 업그레이드 가격 | 시트에 없음("본전 1~2시간"만) → 임시 시작값 |
| 사는 곳 | 물류센터 화면은 v6(건물 클릭)이라, v5에서는 차고에 [기사·물류센터] 칸을 하나 더 만든다 |
| 3분 미만 자리 비움 | 무시 (꺼둔 동안 계산·요약 창 없음). 기획서 15.6 |
| 돌아왔을 때 요약 | 자리 비운 시간, 번 돈, 배송 수, 경험치(v5는 0), 스페어, 그리고 "창고가 꽉 참"(상한에 닿았을 때) |
| 저장 | 형식 5. 형식 4 파일은 읽힘(새 칸은 처음 값, 창고·야간팀 Lv1) |
| 주간 배송 목표·보험 쿠폰 | v6 |

## 계산식

```
다음 레벨까지 경험치(레벨 L) = round(driver.base_xp × L ^ driver.exponent),  L = max_level 이면 0
경험치를 받으면  : driver_xp 에 더하고, 필요량을 넘는 동안 레벨 +1, 남는 경험치는 이어 감
                   만렙이면 받은 만큼 reputation 에 더함 (만렙이 되는 순간 남은 경험치도 reputation 으로)
포인트           : 레벨이 L이 될 때 +driver.points_per_level, L % 10 == 0 이면 +driver.bonus_points_every_10 더
배송 1건 경험치  = driver.xp_per_parcel   (켜 둔 동안 advance 에서만)
강화 첫 달성     : 트럭 단계가 driver.star_milestones 의 값에 처음 닿으면 driver.star_milestone_xp (값마다 한 번, 어느 트럭이든)
꺼둔 동안        : 꺼둔 초 < offline.ignore_under_seconds 이면 아무것도 안 함
                   시간 = min(꺼둔 초 ÷ 3600, depot.warehouse_hours[창고 레벨-1])
                   돈·배송 = v4 식에서 rate 를 depot.night_rates[야간팀 레벨-1] 로
업그레이드 가격  = depot.warehouse_prices[지금 레벨-1] / depot.night_prices[지금 레벨-1]  (지금 레벨 → 다음 레벨)
                   살 수 있는 최고 레벨 = depot.warehouse_max_level_solo (대리점 전)
퀘스트 조건      : 종류별로 "지금 값 ≥ target" (아래 표)
```

퀘스트 조건 종류 (`quests[i].kind`):

| kind | 지금 값 |
|---|---|
| `parcels` | 지금까지 배송한 건수 (켜 둔 동안 + 꺼둔 동안) |
| `star` | 트럭들 중 가장 높은 지금 단계 |
| `setting_rolls` | 세팅 돌린 횟수 |
| `setting_grade` | 부품들 중 가장 높은 등급 (0 순정 ~ 4) |
| `part_rolled` | `part`로 적힌 부품을 돌린 적이 있으면 1 |
| `spares_bought` | 스페어를 산 개수 |
| `warehouse` / `night` | 창고 / 야간팀 레벨 |
| `level` | 기사 레벨 |

## 옮길 숫자

시트에서 옮기는 것 (시작값):

| 시트 탭 | 칸 | 값 | balance.json 키 |
|---|---|---|---|
| 경험치 얻는 법 | B2 | 10 | `driver.xp_per_parcel` |
| 경험치 얻는 법 | B7 | 500 | `driver.star_milestone_xp` |
| 레벨 곡선 | B1:B4 | 100, 1.2, 1, 2 | `driver.base_xp`, `driver.exponent`, `driver.points_per_level`, `driver.bonus_points_every_10` |
| 오프라인 | C2:C5 | 4, 6, 8, 12 | `depot.warehouse_hours` (`offline.cap_hours` 8을 대신함) |
| 오프라인 | C6:C9 | 0.5, 0.6, 0.7, 0.8 | `depot.night_rates` (`offline.rate` 0.5를 대신함) |

기획서에서 온 값: `driver.max_level` 50 (4.8), `offline.ignore_under_seconds` 180 (15.6), `depot.warehouse_max_level_solo` 3 (4.9 "12시간은 대리점부터").
`offline` 묶음에는 `ignore_under_seconds`만 남긴다.

임시 시작값 (시트에 없음):

| balance.json 키 | 값 |
|---|---|
| `driver.star_milestones` | 10, 15, 18, 20, 22, 25, 28, 30 |
| `depot.warehouse_prices` | 2000000, 8000000, 40000000 |
| `depot.night_prices` | 3000000, 12000000, 50000000 |
| `quests` | 아래 22개 (보상 경험치는 시트 "200~1,000" 범위, 돈은 임시) |

```
id                 kind           target  part       xp    money
first_parcel       parcels        1                  200   10000
parcels_20         parcels        20                 200   20000
first_enhance      star           1                  200   30000
first_setting      setting_rolls  1                  200   40000
star_3             star           3                  200   50000
setting_street     setting_grade  1                  300   100000
star_5             star           5                  300   150000
ecu_first          part_rolled    1       ecu        300   150000
warehouse_2        warehouse      2                  300   200000
level_5            level          5                  300   200000
star_8             star           8                  400   300000
setting_sport      setting_grade  2                  400   400000
night_2            night          2                  400   400000
star_10            star           10                 500   600000
level_10           level          10                 500   600000
warehouse_3        warehouse      3                  500   800000
star_12            star           12                 600   1000000
first_spare        spares_bought  1                  600   1000000
star_15            star           15                 800   2000000
level_20           level          20                 800   2000000
setting_racing     setting_grade  3                  1000  3000000
star_18            star           18                 1000  5000000
```

## 코드 약속 (계산 담당 ↔ 화면 담당)

`scripts/core/game_state.gd` (새 칸)
```gdscript
var driver_level: int = 1
var driver_xp: int = 0            ## 지금 레벨에서 쌓은 경험치
var ability_points: int = 0       ## 받은 포인트 (v5에서는 쌓이기만)
var reputation: int = 0           ## 만렙 뒤 경험치
var warehouse_level: int = 1
var night_level: int = 1
var quest_index: int = 0          ## 지금 차례인 퀘스트 번호 (목록 길이면 다 끝남)
var parcels_total: int = 0
var setting_rolls: int = 0
var spares_bought: int = 0
var parts_rolled: Dictionary = {} ## 부품 id → true
var milestones_done: Array = []   ## 보너스를 이미 받은 단계들
func take_events() -> Array       ## 계산 쪽이 쌓아 둔 알림을 꺼내고 비움. 화면이 프레임마다 부른다
##   { "type": "level_up", "level": int, "points": int } / { "type": "max_level" }
##   { "type": "quest_done", "id": String, "xp": int, "money": int } / { "type": "milestone", "star": int, "xp": int }
```

`scripts/core/driver.gd` (새 파일. 굴리기 없음)
```gdscript
static func max_level(b) -> int
static func xp_need(b, level: int) -> int                 ## 그 레벨에서 다음 레벨까지. 만렙이면 0
static func add_xp(state, b, amount: int) -> void          ## 레벨업·포인트·평판 처리 + 알림 쌓기
static func on_star_reached(state, b, star: int) -> void   ## 강화 성공 뒤에 Enhance가 부름 (첫 달성 보너스)
```

`scripts/core/depot.gd` (새 파일. 굴리기 없음. `kind`는 "warehouse" 또는 "night")
```gdscript
static func cap_hours(b, state) -> float
static func rate(b, state) -> float
static func level(state, kind: String) -> int
static func top_level(b, kind: String) -> int              ## 표의 마지막 레벨 (4)
static func buyable_level(b, state, kind: String) -> int   ## 지금 살 수 있는 최고 레벨 (창고는 대리점 전 3)
static func value_at(b, kind: String, level: int) -> float ## 그 레벨의 시간 또는 비율 (화면 표시용)
static func price(b, state, kind: String) -> int           ## 다음 레벨 가격. 더 못 사면 0
static func can_upgrade(b, state, kind: String) -> bool
static func upgrade(b, state, kind: String) -> bool
```

`scripts/core/quest.gd` (새 파일. 굴리기 없음)
```gdscript
static func count(b) -> int
static func current(b, state) -> Dictionary        ## 지금 차례 퀘스트의 json 묶음. 다 끝났으면 {}
static func progress(b, state) -> Array            ## [지금 값, target]. 다 끝났으면 [0, 0]
static func check(state, b) -> bool                ## 지금 차례 퀘스트가 찼으면 보상을 주고 다음으로 (한 번에 하나). 알림을 쌓음
```

바뀌는 것:
- `Trip.advance`: 배송마다 `parcels_total` +1, `Driver.add_xp`, 그리고 한 번 부를 때마다 끝에 `Quest.check` 한 번
- `Trip.apply_offline`: 위 식. 돌려주는 묶음에 `"xp": 0`, `"full": bool`(창고 상한에 닿음), `"ignored": bool`(3분 미만) 추가. `parcels_total`에 더함
- `Enhance.try_enhance` 성공 → `Driver.on_star_reached`. `Setting.try_roll` 성공 → `setting_rolls` +1, `parts_rolled[part]`. `GameState.buy_spare` → `spares_bought` +1
- 강화·세팅·업그레이드·스페어 구매 뒤에는 화면이 `Quest.check(state, b)`를 한 번 부른다 (advance가 다음 프레임에 불러도 되지만 바로 반응하게)
- `Save`: `FORMAT_VERSION := 5`, 위 새 칸 전부. 형식 4는 읽힘. 레벨·인덱스는 범위로 자름

퀘스트 이름·설명은 번역 파일에 (`QUEST_<ID 대문자>` 키). core는 id만.

## 범위

**만드는 것:** 위 전부.
**안 만드는 것:** 능력치 5개·초기화·노하우 꺼둔 동안 경험치(v5b, 시트가 읽히면), 주간 배송 목표·쿠폰(v6), 물류센터 건물 화면(v6), 평판 쓰는 곳(v7), 창고 Lv4 사기(v7).

## 작업 순서와 담당

계산 = `core` 페인, 폴더 `itwasdv-window`, 가지 `v5-core`. 화면 = `ui` 페인, 폴더 `itwasdv-town`, 가지 `v5-ui`.

| 단계 | 담당 | 고치는 파일 | 안 건드리는 파일 | 완료 기준 |
|---|---|---|---|---|
| C1 레벨·퀘스트·창고 계산 | 계산 | `data/balance.json`, `scripts/core/*`, `tests/test_*.gd`(`test_fmt` 빼고), `tests/run_tests.gd` | `scripts/ui/`, `scenes/`, `tests/check_*`, `locale/`, `tools/` | `run_tests` 전부 통과(종료 코드 0). 새 테스트: ① json 값이 "옮길 숫자"와 같음 ② `xp_need` 레벨 1~6이 100, 230, 374, 528, 690, 859 (시트 값), 만렙 0 ③ 경험치를 한 번에 많이 줘도 여러 레벨이 오르고 남는 경험치가 이어짐, 포인트: 레벨 10이 될 때까지 9 + 2 = 11, 레벨 50까지 합 59 ④ 만렙 뒤 경험치 → 평판, 알림 `max_level` 한 번 ⑤ `advance` 배송 n건 → 경험치 10n, `parcels_total` n ⑥ 강화 첫 달성 보너스는 단계마다 한 번(퍼져서 다시 올라가도 안 줌) ⑦ 창고·야간팀: 레벨별 시간·비율, 가격, 돈 모자라면 못 삼, 창고 Lv3에서 더 못 삼(`price` 0), 꺼둔 동안 계산에 반영 ⑧ 179초 자리 비움 → `ignored`, 상태 그대로 / 180초 → 계산함 / 상한 넘으면 `full` ⑨ 퀘스트: 목록 22개, 순서대로 하나씩, 조건을 미리 넘긴 것은 `check`를 부를 때마다 하나씩 끝남, 보상(경험치·돈) 정확히 한 번, 다 끝나면 `current` {} ⑩ 알림: `take_events`가 순서대로 주고 비움 ⑪ 저장: 형식 5 왕복, 형식 4 파일 읽힘(새 칸 처음 값), 이상한 값 자름 ⑫ +0에서 새 게임 → `advance` 1시간: 레벨·끝난 퀘스트 수를 찍음 |
| C2 시뮬 | 계산 | `tools/tune_sim.py` | `tools/`만 고침 | 가상 유저에 레벨(켜 둔 배송 경험치 + 강화 첫 달성 + 퀘스트 보상), 창고·야간팀 사기(규칙은 파일 맨 위)를 넣음. 결과에 만렙까지 걸린 날·켜 둔 시간(가볍게 / 열심히 중앙값), 30일째 창고·야간팀 레벨 분포, 30일째 지금 단계 중앙값을 찍음. `--table`은 그대로 |
| U1 화면 (C1 뒤, `v5-core` 합치고) | 화면 | `scripts/ui/*`, `scenes/`, `tests/check_*.gd`, `locale/*`, `tests/test_fmt.gd` | `scripts/core/`, `data/`, `tools/`, `tests/test_*`(`test_fmt` 빼고) | "기존 확인" 전부 통과 + 새 `tests/check_driver.gd`가 진짜 클릭으로 결과 줄을 찍음: ① 작은 화면에 레벨 "Lv.N"과 지금 퀘스트 한 줄(이름 + 진행 "3/20") ② 차고 [기사·물류센터] 칸: 레벨, 경험치 막대(`driver_xp`/`xp_need`), 받은 포인트, 지금 퀘스트(이름·설명·진행·보상), 끝난 수 "n/22" ③ 퀘스트가 끝나면 알림(이름 + 보상)이 뜨고 돈이 보상만큼 늘고 다음 퀘스트로 바뀜 ④ 레벨업 알림 ("Lv.N" + 포인트), 만렙 알림 ⑤ 창고·야간팀: 지금 값 → 다음 값, 가격, 사면 돈이 줄고 레벨 +1, 돈 모자라면 버튼 꺼짐 + 모자란 금액, 창고 Lv3에서 "대리점부터" 글 ⑥ 업그레이드·강화·세팅 직후 `Quest.check`가 불려 바로 반응 ⑦ 돌아왔을 때 요약: 3시간 / 20시간(창고 꽉 참 글) / 179초(창이 안 뜸) / 시계가 거꾸로(0원 안내) ⑧ 다 끝나면 퀘스트 줄이 "다음 할 일 없음" 글로 ⑨ 산 직후 저장 ⑩ en에서도 칸이 뜨고 키·한글이 안 보임(퀘스트 22개 이름·설명 포함) ⑪ 알림이 여러 개 겹치면 하나씩 차례로 |

화면 글자: 퀘스트 목록의 이름은 "다음 할 일", 건물은 "물류센터", 업그레이드는 "창고 확장" / "야간 배송팀". 알림은 작게 (기획서: 방해되지 않게).

## 플레이 테스트 (사용자가 직접)

새 게임으로 30분. "아니오"가 2개 이상이면 다음 기능보다 숫자·연출부터.

1. 지금 뭘 하면 되는지 늘 보이는가?
2. 퀘스트 보상이 "받을 만한" 크기인가?
3. 레벨업이 반가운가? (지금은 포인트 쓸 곳이 없음)
4. 창고 확장·야간 배송팀이 사고 싶은가?
5. 돌아왔을 때 요약이 한눈에 읽히는가?
