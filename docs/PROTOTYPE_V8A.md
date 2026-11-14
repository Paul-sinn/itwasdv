# 시제품 v8a 지시서: 물류센터 업그레이드, 랩핑 4개, 통계·도감, 업적 20개

> 2026-11-14. 기획서 4.6(랩핑샵), 10장 12·15·18번, 15.9(통계·도감, 업적), 16.6(물류센터 업그레이드), 16.9 v8 [확정].
> v8(기획서 16.9) 중 **게임 내용**만. 설정(띠 크기·모니터·투명도·언어 등)은 v8b. 스팀 연동(업적·클라우드)과 소리는 계정·음원이 필요해 `QUESTIONS.md` Q29에 물어 둠.
> 숫자 시트 = `docs/SHEET_SNAPSHOT.md` 12번(물류센터 업그레이드: 본전 10~30분, 랩핑). 그 밖의 숫자(가격·효과·업적 목록)는 시트에 없어 **임시**로 넣고 시뮬 제안 → 사용자 허락.
> 앞 단계: v7b (`prototype-v7b`). 합치는 곳은 `itwasdv-merge`(가지 `prototype-v8a`). **`itwasdv` 폴더는 건드리지 않는다.**

## 이 시제품으로 알아낼 것 (딱 하나)

**첫 3시간에 "돈 쓸 곳"과 "모을 것"이 충분한가? (물류센터 업그레이드가 초반 병목을 풀어 주고, 업적·도감이 눌러 보고 싶은가)**

## 정한 것

| 항목 | 정한 것 | 근거 |
|---|---|---|
| 물류센터 업그레이드 | 3개 × Lv0 → Lv5 (다섯 번씩 삼). 정해진 값만 오르는 단순 구매. **개인 기사(동네)일 때만 살 수 있고**, 산 효과는 대리점 뒤에도 모든 트럭에 유지 | 기획서 16.6 |
| ① 배송 구역 확장 | 단가 +% (레벨마다). 노선 배수·협상과 곱함 | 기획서 16.6 |
| ② 분류 속도 | 물류센터에서 싣는 시간 −% (레벨마다). 상하차 능력치와 곱함 | 기획서 16.6 |
| ③ 기본 적재함 | 한 바퀴 기본 적재량 +1건 (레벨마다). 적재량 옵션 %·시내 집 수 배수는 그 위에 | 기획서 16.6 |
| 따로 떼기 | `scripts/core/upgrade.gd` 한 파일 + json `depot_upgrades` 묶음. 묶음을 지우면 기능이 꺼지게 (일정이 밀리면 제일 먼저 자름) | 기획서 15.8, 16.6 |
| 랩핑 | 차체 색·무늬만. 성능 없음. 출시 4개: 구매용 2 (게임 돈), 보상용 2 (업적: 첫 +18 성공, 첫 엔진 퍼짐 "위로"). 뽑기 없음. 가진 랩핑을 트럭마다 골라 입힘 (기본 = 랩핑 없음) | 기획서 4.6 |
| 랩핑 사는 곳 | **튜닝숍 화면의 [랩핑] 칸** (랩핑샵 건물은 띠에 자리가 없고 그림이 나온 뒤에) | 조율자가 정함 (Q29) |
| 통계 | 총 배달 수, 총 번 돈, 켜 둔 시간, 최고 강화 단계, 강화 시도·성공·실패·퍼짐 수, 보험이 막은 퍼짐 수, 세팅 돌린 수, 받은 팁 수, 명장 방문 수 | 기획서 15.9 + 조율자가 고름 |
| 도감 | 잡옵 도감: 잡옵 5종 × 등급 5개 = 25칸. 세팅을 돌려 결과에 나온 순간(안 골라도) 칸이 채워지고 본 횟수가 오름. 한 번에 같은 잡옵 3줄이 나오면 그 잡옵 칸에 별 표시 | 기획서 15.9 "컵홀더 수집" |
| 업적 | 20개, 한 번씩. 달성하면 알림. 보상은 2개만 랩핑 (나머지는 보상 없음: 스팀 업적처럼). 목록은 아래 | 기획서 10장 15번, 4.6 |
| 보는 곳 | 물류센터 화면에 [기록] 칸 하나: 통계 / 도감 / 업적 세 묶음 | 조율자가 정함 |

## 옮길 숫자 (`data/balance.json` → 0.18, `docs/numbers-source.md`에 기록. **전부 임시**)

```json
"depot_upgrades": {
  "zone":  { "per_level": 0.02, "prices": [100000, 300000, 800000, 2000000, 5000000] },
  "sort":  { "per_level": 0.06, "prices": [50000, 150000, 400000, 1000000, 2500000] },
  "box":   { "per_level": 1,    "prices": [80000, 250000, 700000, 1800000, 4500000] }
},
"wraps": [
  { "id": "stripe", "price": 1000000 },
  { "id": "flame",  "price": 10000000 },
  { "id": "gold18", "achievement": "star_18" },
  { "id": "bandage", "achievement": "first_destroy" }
],
"achievements": [
  { "id": "first_parcel", "kind": "parcels", "target": 1 },
  { "id": "parcels_10k", "kind": "parcels", "target": 10000 },
  { "id": "parcels_1m", "kind": "parcels", "target": 1000000 },
  { "id": "star_10", "kind": "best_star", "target": 10 },
  { "id": "star_15", "kind": "best_star", "target": 15 },
  { "id": "star_18", "kind": "best_star", "target": 18 },
  { "id": "star_20", "kind": "best_star", "target": 20 },
  { "id": "star_25", "kind": "best_star", "target": 25 },
  { "id": "first_destroy", "kind": "destroys", "target": 1 },
  { "id": "insured_save", "kind": "insured_saves", "target": 1 },
  { "id": "setting_racing", "kind": "setting_grade", "target": 3 },
  { "id": "setting_prototype", "kind": "setting_grade", "target": 4 },
  { "id": "junk_triple", "kind": "junk_triples", "target": 1 },
  { "id": "junk_book_15", "kind": "junk_book", "target": 15 },
  { "id": "level_max", "kind": "level", "target": 50 },
  { "id": "found_agency", "kind": "agency", "target": 1 },
  { "id": "helpers_2", "kind": "helpers", "target": 2 },
  { "id": "contracts_3", "kind": "contracts", "target": 3 },
  { "id": "master_10", "kind": "master_visits", "target": 10 },
  { "id": "rank_first", "kind": "rank_first", "target": 1 }
]
```

- 업그레이드 가격·효과는 시뮬(C3)이 "산 뒤 본전 10~30분(켜 둔 시간)" + "30일 판정이 안 빨라지게" 기준으로 제안. 랩핑 가격도 임시

## 코드 약속

```gdscript
## scripts/core/upgrade.gd (새) — 물류센터 업그레이드
const IDS := ["zone", "sort", "box"]
static func enabled(b) -> bool                                   ## json에 depot_upgrades 묶음이 있나 (없으면 화면도 칸을 숨김)
static func level(state: GameState, id: String) -> int           ## 0~5
static func max_level(b, id: String) -> int
static func price(b, state: GameState, id: String) -> int        ## 다음 레벨 값 (다 샀으면 -1)
static func can_buy(b, state: GameState, id: String) -> bool     ## 개인 기사 + 돈 + 레벨 남음
static func buy(b, state: GameState, id: String) -> bool
static func value(b, state: GameState, id: String) -> float      ## 지금 효과 (zone 0.04 = 단가 +4%, sort 0.12, box 2.0)
## GameState.depot_upgrades: Dictionary (id → 레벨). Trip._unit / 싣는 시간 / 기본 적재량이 Upgrade.value 를 읽음

## scripts/core/wrap.gd (새)
static func ids(b) -> Array                                      ## json 순서
static func owned(state: GameState, id: String) -> bool
static func price(b, id: String) -> int                          ## 구매용이면 값, 보상용이면 -1
static func reward_of(b, id: String) -> String                   ## 보상용이면 업적 id, 아니면 ""
static func can_buy(b, state: GameState, id: String) -> bool
static func buy(b, state: GameState, id: String) -> bool
static func wear(state: GameState, i: int, id: String) -> bool   ## 트럭 i에 입힘 ("" = 벗김). 안 가진 랩핑이면 false
## GameState.wraps: Array (가진 id), TruckState.wrap: String

## scripts/core/stats.gd (새)
static func get_all(state: GameState) -> Dictionary              ## { "parcels", "money_earned", "seconds_on", "best_star", "tries", "successes", "fails", "destroys", "insured_saves", "setting_rolls", "tips", "master_visits" }
static func junk_book(b, state: GameState) -> Array              ## [{ "option": id, "grade": int, "seen": int, "triple": bool }] 25칸 (json 순서 × 등급)
static func junk_book_count(state: GameState) -> int             ## 채운 칸 수
static func tick(state: GameState, dt: float) -> void            ## 켜 둔 시간. 화면이 프레임마다
## 세는 곳은 계산 코드 안 (Trip·Enhance·Setting·Master). GameState.stats: Dictionary, junk_seen: Dictionary

## scripts/core/achievement.gd (새)
static func all(b) -> Array                                      ## json 목록
static func is_done(state: GameState, id: String) -> bool
static func progress(b, state: GameState, id: String) -> Array   ## [지금, 목표]
static func check(state: GameState, b) -> void                   ## 새로 달성한 것마다 이벤트 { "type": "achievement", "id": id, "wrap": 랩핑 id 또는 "" } + 랩핑 지급. 화면이 프레임마다 (또는 계산이 바뀌는 곳에서 — 보고에)
## GameState.achievements_done: Array

## Save: 형식 13 (새 칸). 형식 12는 기본값으로 읽음. 옛 저장의 통계는 이미 있는 칸(parcels_total, 트럭 success_count 등)에서 채울 수 있는 것만 채움
```

- 화면이 쓰는 계산은 위 함수만. 더 필요하면 계산 담당이 만들고 보고에 적는다
- (2026-11-14 구현 뒤 약속에 넣음) `Upgrade.value_at(b, id, lv) -> float`, `Wrap.for_achievement(b, achievement_id) -> String`, `Stats.best_star(state) -> int`, `Stats.cell(option, grade) -> String`, `GameState.junk_triples`. 화면이 프레임마다 `Stats.tick`·`Achievement.check`. 업적 알림은 그 프레임 것을 하나로 묶음
- (2026-11-14 시뮬 뒤 넣은 숫자, json 0.19. 위 "옮길 숫자"는 임시였음) 업그레이드 효과 zone 0.01·sort 0.03·box 0.4 (소수 허용), 값 zone [3700, 110000, 150000, 240000, 410000]·sort [790, 47000, 56000, 73000, 160000]·box [6500, 230000, 260000, 370000, 490000], 랩핑 800만·3,000만, 라이벌 2,700만 ~ 4,830만 (`_reports/core_v8a_c4.md`, QUESTIONS Q30)

## 화면

| 곳 | 바뀌는 것 |
|---|---|
| 물류센터 [창고·할 일] 칸 | 업그레이드 3줄: 이름, Lv N / 5, 지금 효과 → 다음 효과, [값] 버튼. 대리점이면 버튼 대신 "동네에서만 살 수 있어요 (효과는 유지)". `Upgrade.enabled`가 거짓이면 줄을 숨김 |
| 튜닝숍 [랩핑] 칸 | 랩핑 4개 카드: 미리 보기(트럭 색·무늬), 이름, [값] / "업적: …로 받음" / [입히기] / "입는 중". 트럭 탭에서 고른 트럭에 입힘 |
| 띠·큰 화면 트럭 | 입힌 랩핑대로 차체 색·무늬 (코드로 그리는 임시 도형: 줄무늬, 불꽃, 금색, 반창고). 보조 트럭도 |
| 물류센터 [기록] 칸 | 통계 12줄 / 잡옵 도감 25칸 (안 본 칸은 "?", 본 횟수, 3줄 별) / 업적 20줄 (달성 표시, 진행 N / 목표, 랩핑 보상 표시). 길면 스크롤 |
| 알림 | "업적 달성: …" (+ "랩핑 '…' 받음"), 업그레이드 구매 |
| 글 | ko·en 둘 다 (업적·랩핑·통계 이름) |

- 확인 스크립트: `tests/check_v8a.gd` (새). 완료 기준마다 결과 줄

## 시뮬 (`tools/tune_sim.py`)

`_reports/balance_v8a.md` + `_reports/v8a_proposal.diff` (json에는 안 넣음).

1. 업그레이드 15번의 가격: 가볍게 유저가 그 레벨을 살 만한 때(직전 레벨을 산 뒤)에 **산 뒤 본전이 켜 둔 시간 10~30분**. 다 사는 때가 창업 전(가볍게 2~3주 안)인지
2. 효과 크기(단가 +10%, 싣기 −30%, 적재 +5건)가 30일 판정(+18 / +20)을 얼마나 당기는지. 빨라지면 효과를 줄인 제안 (강화 비용 65,000 등 허락받은 숫자는 그대로)
3. 첫 3시간에 "새로운 것"(퀘스트 완료 + 업그레이드 구매 + 업적)이 몇 번 나오는지 (목표: 10번 이상)
4. 랩핑 가격 2개: 구매용 첫째는 첫 주 안, 둘째는 창업 전후에 살 만한 값

## 범위

- 넣음: 위 전부
- 안 넣음: 설정 (v8b), 스팀 업적·클라우드, 소리, 랩핑샵 건물·NPC 그림, 외형 고정 옵션

## 작업 순서와 담당

| 단계 | 담당 (가지) | 내용 | 완료 기준 |
|---|---|---|---|
| C1 | 계산 (`v8a-core`) | 물류센터 업그레이드 (upgrade.gd, Trip 반영), 저장 13 | `run_tests` 통과 (레벨·가격·대리점이면 못 삼·효과 유지·한 바퀴 계산·json 묶음 없으면 꺼짐). 보고 `_reports/core_v8a_c1.md` |
| C2 | 계산 | 랩핑, 통계, 도감, 업적 | `run_tests` 통과 (업적 20개 조건마다, 랩핑 보상, 도감 칸, 통계 세기, 저장 왕복). 보고 `core_v8a_c2.md` |
| C3 | 계산 | 시뮬 4항목 | `_reports/balance_v8a.md`, `v8a_proposal.diff` |
| U1 | 화면 (`v8a-ui`) | C1 합친 뒤: 업그레이드 줄. 그 전에: [랩핑] 칸·트럭 랩핑 그림·[기록] 칸 틀 | 기존 확인 전부 + `check_v8a.gd` 통과. 보고 `ui_v8a_u1.md` |
| U2 | 화면 | C2 합친 뒤: 랩핑·기록 칸 연결, 알림 | 확인 전부 통과. 보고 `ui_v8a_u2.md` |
| 합치기 + QA | 조율자, core 페인 | | 확인 전부 통과, QA 보고 `_reports/qa_v8a.md` |

- 담당 파일: 계산 = `scripts/core/`, `data/`, `tests/test_*.gd`, `tools/`. 화면 = `scripts/ui/`, `scenes/`, `tests/check_*.gd`, 번역 파일

## 플레이 테스트 (사용자가 직접)

1. 첫 3시간에 물류센터 업그레이드를 사고 싶었나, 사고 나서 빨라진 게 느껴졌나? (예 / 아니오)
2. 랩핑을 사거나 받았을 때 띠의 트럭을 다시 봤나? (예 / 아니오)
3. [기록] 칸을 스스로 열어 봤나? 도감을 채우고 싶었나? (예 / 아니오)
4. 업적 알림이 반가웠나, 귀찮았나? (예 / 아니오)
