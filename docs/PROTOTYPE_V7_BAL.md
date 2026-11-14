# 시제품 v7-bal 지시서: 사용자 답 반영 (이벤트 다시 짜기, 시내, 허락받은 숫자)

> 2026-11-14. 사용자 답: 바깥 폴더 `QUESTIONS.md` Q17~Q25 답 + 맨 아래 "사용자 답 3 (최종)". 기획서 4.7, 16.10 [확정].
> 숫자 시트 = `docs/SHEET_SNAPSHOT.md` (시트 버전 25) 4·5·6·9·10·13번.
> 사용자가 정한 순서: **이 지시서(보험사·시내·옵션 수치) → 시뮬 다시 → v7b(장거리·터보, 기업 계약)**.
> 앞 단계: v7a (`prototype-v7a`). 합치는 곳은 `itwasdv-merge`(가지 `prototype-v7-bal`). **`itwasdv` 폴더는 건드리지 않는다.**

## 이 시제품으로 알아낼 것 (딱 하나)

**NPC가 오는 날(명장·보험사·마술사·부품상)이 "오늘은 이걸 지르는 날"로 느껴지는가? (보험을 들고 지르는 날이 손해가 아닌가)**

## 정한 것

| 항목 | 정한 것 | 근거 |
|---|---|---|
| 명장 방문일 | 강화 버프만. 보너스 3개 중 1개 랜덤: 퍼짐 확률 30% 감소 / 강화 성공 확률 1.2배 / 성공 시 10%로 한 단계 더(+30 상한). **보험 없음.** 요일 고르기·전날 예고·하루 동안만은 그대로 | 답 3 |
| 뺀 명장 보너스 | 강화 비용 할인, 세팅 등급업 확률, 스페어 드랍 2배, 세팅 비용 할인 → 코드·json·글에서 지움 | 답 3 |
| 특별 NPC 3명 | 보험사·마술사·중고 부품상. 각자 **21~28일에 한 번 랜덤, 현지 날짜 하루(0~24시)** 머묾. 그날 게임을 안 켰으면 그 방문은 지나감 | 답 3 |
| NPC 규칙 | 하루에 NPC 한 명. 명장 요일엔 특별 NPC가 안 옴. 겹치면 다음 날로 미룸 (정해진 순서: 보험사 → 마술사 → 부품상) | 답 3 |
| 특별 NPC가 열리는 때 | 명장과 같이 엔진 +10 첫 달성 (조율자가 정함 → QUESTIONS Q26) | 기획서 16.4 |
| 보험 | 보험사가 온 날 **[예]를 누른 경우에만.** 그날 하루, 지금 단계의 퍼짐 확률이 0보다 큰 강화(+18 이상)를 누를 때마다 보험료가 강화 비용과 같이 나감. 그 회는 퍼짐이 나와도 실패(단계 유지). 성공·실패 확률 그대로. 스페어 없이도 누를 수 있음 (지금 규칙) | 답 3 |
| 보험료 | `반올림(그 회 강화 비용(할인 전) × 그 단계 퍼짐 확률(표 값, 엔진 보호·명장 반영 전) × fee_mult 10)`. 강화 비용 + 보험료가 없으면 못 누름 (돈 부족) | 답 3. "표 값"은 조율자가 정함 (Q26) |
| 보험사 이벤트 | 방문마다 1개 랜덤. **제휴 할인:** 그날 [예] 한 사람은 강화 비용 50% (모든 단계. 보험료는 원래 강화 비용 기준) / **복구 보험:** 그날 [아니오](또는 안 누름) 상태로 퍼지면 +15 대신 +17에서 재시작 (스페어는 평소처럼 1개 씀) | 답 3. "모든 단계"는 조율자가 정함 (Q26) |
| [예] 뒤 | 그날은 되돌릴 수 없음. [아니오]를 눌렀어도 그날 안에는 다시 열어 [예] 가능 | 조율자가 정함 (Q26) |
| 보험 쿠폰 | 없앰. 저장·화면·주간 보상에서 지움 | 답 3 |
| 마술사 | 그날 하루 세팅 등급업 확률 × 2. 천장 카운터는 그대로 쌓임 | 답 3 |
| 중고 부품상 | 고급 스페어 엔진 1개 선물 (봉투를 안 눌러도 그날 처음 tick에서 자동). 고급 스페어 = 퍼졌을 때 쓰면 +15 대신 **+17**에서 재시작. 보관 가능 | 답 3 |
| 고급 스페어 쓰는 법 | 강화 화면에 [고급 스페어 쓰기] 켜기/끄기 (기본 끔, 저장). 켜져 있고 1개 이상이면 퍼질 때 고급을 먼저 씀. "+18 이상은 스페어 1개" 조건은 보통·고급 합쳐서 봄. 꺼져 있고 보통 스페어가 0이면 못 누름 | 조율자가 정함 (Q26). "보관했다가 아무 때나 씀" |
| 복구 보험 + 고급 스페어 | 둘 다 +17이라 겹쳐도 +17 | |
| 급송 전화 | 벨 **5분(300초)**, 받으면 내 트럭 다음 **50건** ×2 (대형·VIP면 곱함). 띠의 전화 아이콘을 누르면 큰 화면을 안 열고 바로 받음 | 답 3 |
| 주간 배송 목표 | **6만 건.** 보상 = 돈(그 시점 하루치 수입) + 경험치 2,000. 첫 주 규칙 없음 | Q21-2, 답 3 |
| 하루치 수입 | `Company.hourly_net(b, state) × weekly.reward_hours(24)` (받는 순간 켜 둔 상태 기준, 내림) | 조율자가 정함 (Q26). 시뮬로 효과 확인 |
| 상하차 속도 | 집 앞 정차 시간 + **물류센터에서 싣는 시간**도 같은 %로 줄임 | Q19-3 (나) |
| 줄어드는 옵션 상한 | 기름값 절감 최대 60%, 정비비 감소 최대 60% **각자 따로** | Q25-5 |
| 시내 (대리점 무대) | 창업하면 모든 트럭이 시내 노선: **단가 × price_mult, 도로 길이 × road_mult(짧게), 한 바퀴 집 수 × stops_mult(많게)**. 경험치 15는 그대로. 배경 그림이 도시로 (띠 포함), 집·회사 건물이 늘어남 | Q23 |
| 시내 목표 | 상하차 최대(30%)의 수입 효과가 동네의 2배 이상. 창업하면 "확 더 번다" | Q23, 스냅샷 13번 |
| 노선 틀 | `routes`에 town / city (v7b에서 long 추가, 트럭마다 스위치). 이번엔 회사 단계로만 정해짐: 개인 기사 = town, 대리점 = city | Q23, Q24 |

## 옮길 숫자 (`data/balance.json` → 0.14, `docs/numbers-source.md`에 기록)

**허락받은 것 (그대로 넣음):**

| 키 | 지금 | 새 값 | 근거 |
|---|---|---|---|
| `engine.cost_base` | 35000 | 65000 | Q21-1 |
| `engine.spare_drop_chance` | 0.00005 | 0.000006 | Q17-2 |
| `setting.options.fuel_cut.values` | 10~60% | [0.07, 0.12, 0.2, 0.3, 0.45] | Q17-3 |
| `setting.options.cargo.values` | 5~30% | [0.035, 0.055, 0.085, 0.14, 0.21] (시작값. 시뮬로 "이동 속도 한 줄의 약 1.3배") | Q17-3 |
| `setting.cost_cut_cap` | 0.6 (합쳐서) | 지우고 `fuel_cut_cap` 0.6, `maint_cut_cap` 0.6 | Q25-5 |
| `weekly.target_parcels` | 30000 | 60000 | Q21-2 |
| `weekly` | xp 2000, coupons 1 | xp 2000, reward_hours 24 (coupons 지움) | 답 3 |
| `rush` | ring 30, parcels 20 | ring_seconds 300, parcels 50 | 답 3 |
| `company.agency_price` | 5억 | 300000000 | Q25-1 |
| `company.helper_prices` | [500만, 2,000만] | [5000000, 8000000] | Q25-2 |
| `company.rivals` | 800만~3,040만 | [6000000, 7000000, 7700000, 8500000, 9400000, 10400000, 11500000, 12700000, 14000000, 15500000] (Q25-3. 시내 단가를 넣은 뒤 시뮬로 다시 제안) | Q25-3 |
| `master` | 보너스 7개, insure_fee_mult | `{ "unlock_star": 10, "bonuses": { "destroy_cut": 0.3, "success_mult": 1.2, "double_step": 0.1 } }` | 답 3 |

**새로 넣는 것 (임시 표시는 시뮬 제안 → 사용자 허락 뒤 바꿈):**

```json
"visitors": {
  "min_days": 21, "max_days": 28,
  "insurer": { "fee_mult": 10, "events": { "partner_discount": 0.5, "recovery_star": 17 } },
  "magician": { "up_mult": 2 },
  "dealer": { "premium_spares": 1, "premium_drop_to": 17 }
},
"routes": {
  "town": { "price_mult": 1.0, "road_mult": 1.0, "stops_mult": 1.0 },
  "city": { "price_mult": 1.5, "road_mult": 0.5, "stops_mult": 1.5 }
}
```

- `routes.city` 세 숫자는 **임시** (사용자: "배수는 밸런스 담당이 제안"). `maint_cut.values`는 **임시 [0.15, 0.30, 0.45, 0.55, 0.60]** (답: 5배인데 한 줄이 상한 60%를 넘는 등급은 상한 안에서 다시 → 시뮬 제안)
- `stops_mult`: 한 바퀴에 싣는 수 = 적재량 × stops_mult (소수는 지금처럼 확률). 집 수가 느니 정차·싣는 시간도 그만큼 늚

## 코드 약속

```gdscript
## scripts/core/visitor.gd (새) — 특별 NPC 3명
const IDS := ["insurer", "magician", "dealer"]
static func is_unlocked(state: GameState) -> bool                      ## = Master.is_unlocked
static func today(state: GameState) -> String                          ## 오늘 와 있는 특별 NPC id, 없으면 ""  (state.visitor_today)
static func tick(state: GameState, b: Balance, now_local: int, rng: RandomNumberGenerator) -> void
    ## Master.tick 뒤에 부름 (Master.tick 안에서 불러도 됨 — 보고에 적기). 날짜가 바뀌면 오늘 방문자를 다시 정함.
    ## 방문이 시작되면 이벤트 { "type": "visitor", "who": id, "event": 보험사 이벤트 id 또는 "" } 한 번
    ## 부품상이면 그 자리에서 premium_spares += n, 이벤트에 "gift": n
static func insurer_event(state: GameState) -> String                  ## "partner_discount" / "recovery" / "" (보험사가 없는 날)
static func join_insurance(state: GameState, now_local: int) -> bool   ## 보험사가 온 날만 true. 그날 가입 표시
static func is_insured(state: GameState) -> bool                       ## 오늘 가입했나
static func next_day(state: GameState, id: String) -> int              ## 다음 방문 날짜 번호 (확인·시뮬용)

## GameState (새 칸)
var premium_spares: int = 0        ## 고급 스페어
var use_premium: bool = false      ## [고급 스페어 쓰기]
var visitor_next: Dictionary = {}  ## id → 다음 방문 날짜 번호 (현지 날짜). 없으면 첫 tick에서 굴림
var visitor_today: String = ""     ## 저장 안 함 (tick이 채움)
var visitor_day: int = -1          ## visitor_today를 정한 날
var insurer_event: String = ""     ## 오늘 보험사 이벤트 (저장: 같은 날 껐다 켜도 같게)
var insured_day: int = -1          ## [예]를 누른 날짜 번호
## 지움: coupons

## Enhance (바뀜: insure 인자 없어짐. 보험은 state가 정함)
static func chances_for(b, state: GameState, i: int) -> Dictionary
static func insure_fee(state: GameState, b, i: int) -> int             ## 지금 누르면 나갈 보험료 (가입 안 했거나 퍼짐 0이면 0)
static func block_reason(state, b, i: int) -> Block                    ## Block.NO_INSURE 지움
static func try_enhance(state, b, i: int, rng) -> Dictionary           ## { "result", "insured": bool(보험이 퍼짐을 막았나), "double": bool, "drop_to": int(퍼졌을 때 내려간 단계, 아니면 -1), "premium": bool(고급을 썼나) }
static func can_insure(...)                                            ## 지움
## Economy
static func enhance_cost(b, star: int, s: GameState) -> int            ## 제휴 할인(가입한 날) 반영. 보험료는 안 들어감
static func tries(s, b, i: int) -> int                                 ## 강화 비용 + 보험료 기준
## Setting.up_chance(b, grade, s): 마술사 날 × up_mult.  Setting.roll_cost(b, grade, s): 할인 없어짐 (인자는 그대로 둠)
## Master.week_bonus / active_bonus: id 3개만. Master.tick 인자 그대로
## Rush: ring_seconds·parcels 숫자만. Rush.accept 그대로
## Weekly.add_parcels: 달성하면 money += Weekly.reward_money(b, state), 이벤트 { "type": "weekly_done", "money": n, "xp": n }
static func reward_money(b, state: GameState) -> int                   ## 지금 받으면 얼마인가 (화면 표시용)

## Trip (노선)
static func route_id(s: GameState, i: int) -> String                   ## "town" / "city" (v7b에서 "long")
## Trip._unit 에 price_mult, 도로 길이에 road_mult, 한 바퀴 싣는 수에 stops_mult. lap_cargo·cargo·lap_seconds·hourly_* 모두 반영
## Trip._stop 과 싣는 시간 둘 다 상하차 %로 줄임
## 기름값 절감 합은 fuel_cut_cap, 정비비 감소 합은 maint_cut_cap 에서 각각 자름

## Save: 형식 11. 새 칸 저장, coupons 지움. 출시 전이라 옛 파일은 지금 규칙대로(이름 바꿔 남기고 새로 시작)
```

- 화면이 쓰는 계산은 위 함수만. 더 필요하면 계산 담당이 만들고 보고에 적는다 (조율자가 이 약속에 넣음)
- `insure` 인자를 지우면 화면·확인 스크립트가 깨진다 → 계산 C1 커밋에서 화면 쪽 호출은 **컴파일만 되게 최소로** 고치지 말고, 화면 담당이 U1에서 고친다. 대신 C1은 `scripts/core`와 `tests/test_*.gd`만 통과시키고 보고에 "화면이 고칠 호출 목록"을 적는다

## 화면

| 곳 | 바뀌는 것 |
|---|---|
| 강화 화면 | [보험] 켜기 버튼·쿠폰 표시 지움. 가입한 날에는 "보험 가입 중 · 보험료 +N" 줄과 합계(강화 비용 + 보험료), 제휴 할인이면 할인된 비용. +17 이하는 보험료 줄 없음. [고급 스페어 쓰기] 켜기/끄기 + 보통·고급 개수. "보험 덕분에 살았어요!" 연출 그대로. 퍼졌을 때 "+17에서 다시"(고급·복구 보험) 구분 |
| [명장] 칸 | 보너스 3개만. 보험 글 지움 |
| 편지봉투 | 명장·보험사·마술사·부품상이 와 있는 날 화면 오른쪽 위에 **편지봉투 + 느낌표** (띠·큰 화면 둘 다). 띠에서 누르면 큰 화면(설정한 전체화면/창)으로 바뀌고 NPC 대화 창이 뜸. 한 번 열면 느낌표만 꺼지고 봉투는 그날 동안 남음 |
| NPC 대화 창 | 명장·마술사·부품상: 대사 한 번 + 오늘 효과 한 줄 + [닫기]. 보험사: 오늘 이벤트 설명 + 보험료 규칙 한 줄 + [예] [아니오]. 가입 뒤에는 "가입됨" |
| 급송 전화 | 띠와 큰 화면에 **전화 아이콘** (말풍선 대신). 누르면 바로 받음 (큰 화면으로 안 바뀜). 5분. 남은 건수 표시는 그대로 |
| 물류센터 | 주간 목표 보상 글: "돈 N(지금 받으면) + 경험치 2,000". 쿠폰 글 지움 |
| 세팅 화면 | 마술사 날이면 등급업 확률 옆에 "마술사 ×2" |
| 시내 그림 | 창업하면 배경이 도시로 (띠·큰 화면), 집 사이에 회사 건물이 섞이고 정차할 곳이 늘어남. 그림은 지금 방식(코드로 그리는 도형·임시 그림)으로. 그림 목록 문서가 있으면 보험사·마술사·부품상·도시 배경을 추가 |
| 글 | 한국어·영어 번역 파일 둘 다. 메이플 용어("큐브" 등)는 화면에 안 씀: "세팅 돌리기" |

- 확인 스크립트: `tests/check_v7bal.gd` (새). 완료 기준마다 결과 줄. 날짜는 `main.now_local_override`로
- 기존 `check_v6b.gd`의 보험·쿠폰 줄은 새 규칙으로 고치거나 지움 (지운 줄은 보고에 적기)

## 시뮬 (`tools/tune_sim.py`)

새 규칙을 전부 넣고 `_reports/balance_v7bal.md` + `_reports/v7bal_proposal.diff` (json에는 안 넣음). 판정 = **창업 자금을 안 모으는 유저**, 30일째 지금 단계 중앙값.

1. 30일: 가볍게 +18 / 열심히 +20 (cost_base 65,000, 새 옵션·이벤트·주간 보상 포함). 어긋나면 제안
2. 옵션 한 줄 가치 (이동 속도 한 줄 = 1): 기름값 절감(공용, 0.5~1), 적재량(전용, 약 1.3 → 수치 제안), 정비비 감소(전용, 상한 60% 안에서 수치 제안. 상한 때문에 1.3이 안 되면 그 사실과 대안), 오버부스트
3. 보험: 보험사 날 가입해 지르는 유저가 안 쓰는 유저보다 30일 단계가 낮지 않은가 (가볍게·열심히). 제휴 할인 날 / 복구 보험 날 각각 기대값
4. 마술사 ×2: "그날 세팅을 몰아 돌릴 만한가" (등급별 기대 비용 절감)
5. 급송 50건 ×2의 수입 효과 (받는 비율 100% / 50%), 주간 보상(하루치 = 24시간)의 30일 효과
6. 시내: price_mult·road_mult·stops_mult 제안 (창업 직후 수입이 눈에 띄게 오르고, 상하차 최대 효과가 동네의 2배 이상). 그 값에서 창업 3억·보조 트럭 값이 본전 기준(스냅샷 12번)에 맞는지
7. 라이벌 10곳 다시: 가볍게 유저 80% 이상이 90일 안에 1위, 가볍게 10~12주·열심히 6~8주
8. 스페어 드랍: 가볍게 약 2주에 1개 (정비 지식 최대 약 1주)

## 범위

- 넣음: 위 전부
- 안 넣음 (v7b): 장거리 노선·트럭마다 노선 스위치, 터보, 기업 계약. (v8): 랩핑, 통계·도감, 업적, 설정, 스팀, 물류센터 업그레이드

## 작업 순서와 담당

| 단계 | 담당 (가지) | 내용 | 완료 기준 |
|---|---|---|---|
| C1 | 계산 (`v7bal-core`) | 허락받은 숫자, 명장 3개, 보험 다시(visitor.gd·보험사·제휴 할인·복구 보험), 마술사, 부품상·고급 스페어, 쿠폰 지움, 급송·주간 보상, 상하차 싣는 시간, 상한 따로, 저장 11 | `run_tests` 통과 (새 테스트: 방문 일정·하루 한 명·명장 날 피함·보험료 식·+17 이하 보험료 0·제휴 할인·복구 보험·고급 스페어·마술사 ×2·주간 돈 보상·저장 왕복). 보고 `_reports/core_v7bal_c1.md`에 화면이 고칠 호출 목록 |
| C2 | 계산 | 노선 틀 + 시내 (routes, Trip 반영, 꺼둔 동안 포함) | `run_tests` 통과 (창업 전후 한 바퀴 시간·수입, 상하차 효과 비교 테스트). 보고 `core_v7bal_c2.md` |
| C3 | 계산 | 시뮬 8항목 | `_reports/balance_v7bal.md`, `v7bal_proposal.diff` |
| U1 | 화면 (`v7bal-ui`) | C1 합친 뒤: 강화 화면·[명장] 칸·물류센터·세팅 화면·급송 전화 아이콘, 깨진 호출 고치기 | 기존 확인 전부 + `check_v7bal.gd` ①~ 통과. 보고 `ui_v7bal_u1.md` |
| U2 | 화면 | 편지봉투 + NPC 대화 창 4명, 보험사 [예/아니오] | `check_v7bal.gd` 통과. 보고 `ui_v7bal_u2.md` |
| U3 | 화면 | C2 합친 뒤: 시내 그림(도시 배경, 회사 건물, 정차 늘어남), 띠 | 확인 전부 통과. 보고 `ui_v7bal_u3.md` |
| 합치기 + QA | 조율자, core 페인 | | 확인 전부 통과, QA 보고 `_reports/qa_v7bal.md` |

- C1이 시작하는 동안 화면은 **C1과 안 겹치는 것부터**: 편지봉투·NPC 대화 창 틀(U2의 그림·배치), 전화 아이콘. C1 커밋을 합친 뒤 계산 함수에 연결
- 담당 파일: 계산 = `scripts/core/`, `data/`, `tests/test_*.gd`, `tools/`. 화면 = `scripts/ui/`, `scenes/`, `tests/check_*.gd`, 번역 파일

## 플레이 테스트 (사용자가 직접)

1. 명장 날에 "오늘 지르자"는 마음이 들었나? (예 / 아니오)
2. 보험사가 온 날 [예]를 누를지 고민이 되었나, 보험료가 납득되었나? (예 / 아니오)
3. 마술사 날에 세팅을 몰아서 돌렸나? (예 / 아니오)
4. 편지봉투·전화 아이콘이 일하는 데 방해되지 않았나? (예 / 아니오)
5. 창업한 뒤 "시내에 왔다"가 눈에 보였나, 버는 속도가 달라졌나? (예 / 아니오)
