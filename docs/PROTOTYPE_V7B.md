# 시제품 v7b 지시서: 장거리 노선 + 터보, 기업 계약

> 2026-11-14. 사용자 답: 바깥 폴더 `QUESTIONS.md` Q24-1, Q24-2 ("추천대로"). 기획서 4.2, 4.10, 16.4, 16.5, 16.10 [확정].
> 숫자 시트 = `docs/SHEET_SNAPSHOT.md` 2번(터보), 5번(장거리 속도 5~30%), 6번(협상), 7번(장거리 경험치 30), 11번(기업 계약).
> 앞 단계: v7-bal (`prototype-v7-bal`). 합치는 곳은 `itwasdv-merge`(가지 `prototype-v7b`). **`itwasdv` 폴더는 건드리지 않는다.**

## 이 시제품으로 알아낼 것 (딱 하나)

**트럭마다 노선을 고르는 것이 "이 트럭은 속도 세팅이니 장거리, 저 트럭은 시내"처럼 고민거리가 되는가? (아니면 한쪽이 늘 정답인가)**

## 정한 것

| 항목 | 정한 것 | 근거 |
|---|---|---|
| 장거리 노선이 열리는 때 | 대리점 + **그 트럭** 엔진 지금 단계 +10 이상. 퍼져서 +10 아래가 될 일은 없음(+15로 내려감) | 기획서 16.4. "그 트럭"은 조율자가 정함 (대형·VIP와 같은 "지금 단계" 규칙) |
| 노선 스위치 | 대리점부터 트럭마다 [시내 / 장거리]. 기본 시내. 저장. 바꾸면 **다음 바퀴부터** 적용 (이번 바퀴는 실은 대로 끝냄) | Q24-1. "다음 바퀴부터"는 조율자가 정함 (지금 "실은 건수는 다음 바퀴부터" 규칙과 같게) |
| 장거리 한 바퀴 | 도로 길이 × 5, 단가 × 4, 한 바퀴 집 수 × 1 (동네와 같은 20), 경험치 30/건 (내 트럭만) | Q24-1, 스냅샷 7번 |
| 장거리와 다른 규칙 | 대형·VIP·급송·팁·스페어 드랍·기름값·정비비·세금·직원 몫은 시내와 같은 규칙 (단가만 다름) | 가장 단순하게 |
| 터보 | 네 번째 세팅 부품. 장거리가 열리는 조건과 같음 (대리점 + 그 트럭 +10). 옵션: 이동 속도, 기름값 절감(공용), **장거리 속도(전용) 5 / 8 / 12 / 20 / 30%**, 잡옵 5개 | 스냅샷 2·5번 |
| 장거리 속도 옵션 | 장거리 노선을 도는 동안에만 이동 속도 %에 더함 (다른 속도 %와 더하기). 시내에서는 효과 없음 | 스냅샷 5번, 기획서 16.2 "%끼리 더함" |
| 기업 계약 | 대리점에서 회사 평판이 기준에 닿을 때마다 1개 자동 체결 (최대 3). 고르기·관리 없음. 맺어질 때 알림 | 기획서 16.5 |
| 계약 수입 | 계약마다 시간당 고정 금액. **맺는 순간** `Company.hourly_sales × 비율(5 / 7 / 10%)`로 금액이 정해져 그대로 유지 (저장). 협상 능력치 %만큼 더 (지금 찍은 값 기준으로 그때그때). 트럭 시간 안 씀 | Q24-2, 스냅샷 11번 |
| 계약 돈이 들어오는 법 | 켜 둔 동안 초마다 쌓여 정수로 들어옴 (소수는 이월). 세금은 뗌 (번 돈), 직원 몫은 없음. 오늘 매출·장부에 "기업 계약" 줄. 순위표 매출(`hourly_sales`)에는 **안 넣음** (트럭 배송 매출로만 경쟁) | 기획서 4.10. 순위에 안 넣는 것은 조율자가 정함 (계약 금액이 매출에서 나오므로 서로 물리지 않게) |
| 꺼둔 동안 | 계약 수입 × 야간 배송팀 % × 창고 상한 시간까지 | 기획서 16.5 |
| 평판 | 지금 규칙 그대로 (만렙 뒤 경험치가 평판으로). 기준 숫자는 **노하우를 안 찍은 가볍게 유저가 만렙 뒤 1 / 3 / 6주쯤** 닿는 값 | Q24-2 |
| 퀘스트 | 목록 끝에 3개 더: 장거리 노선 처음 보내기, 터보 처음 돌리기, 기업 계약 1개 | 기획서 16.5 |

## 옮길 숫자 (`data/balance.json` → 0.16, `docs/numbers-source.md`에 기록)

```json
"routes": {
  "long": { "price_mult": 4.0, "road_mult": 5.0, "stops_mult": 1.0, "xp_per_parcel": 30, "unlock_star": 10 }
},
"setting": {
  "parts": {
    "turbo": { "unlock": "agency", "unlock_star": 10,
      "options": ["speed", "fuel_cut", "long_speed", "junk_ride", "junk_scent", "junk_cupholder", "junk_radio", "junk_gloss"] }
  },
  "options": {
    "long_speed": { "kind": "own", "weight": 10, "values": [0.05, 0.08, 0.12, 0.2, 0.3] }
  }
},
"contracts": {
  "reputation": [150000, 450000, 900000],
  "sales_share": [0.05, 0.07, 0.10]
}
```

- `routes.long.price_mult` 4.0과 `contracts.reputation` 세 숫자는 **임시** (사용자: "단가 4배쯤", "숫자는 시뮬로 제안"). C3 시뮬이 제안 → 사용자 허락 뒤 바꿈
- 퀘스트 3개의 보상은 앞 퀘스트(창업 뒤 3개)와 같은 크기로 계산 담당이 정하고 보고에 적는다

## 코드 약속

```gdscript
## TruckState (새 칸, 저장)
var route: String = ""            ## "" = 기본 (개인 기사 town, 대리점 city). "long" = 장거리. 스위치가 바꾸는 값
var lap_route: String = ""        ## 이번 바퀴가 도는 노선 (바퀴 출발 때 정함. 저장)

## Trip
static func route_id(s: GameState, i: int) -> String          ## 이번 바퀴 노선 "town" / "city" / "long" (계산·화면 모두 이것)
static func route_choice(s: GameState, i: int) -> String      ## 스위치 값 "city" / "long" (다음 바퀴부터 적용될 노선)
static func can_long(b, s: GameState, i: int) -> bool         ## 대리점 + 그 트럭 +10 이상
static func set_route(b, s: GameState, i: int, id: String) -> bool   ## "city" / "long". 못 고르면 false
static func hourly_income_on(b, s, i: int, id: String) -> float     ## 그 노선으로 돌 때 시간당 번 돈 (스위치 옆 비교 표시용)
static func lap_seconds_left(b, s, i: int) -> float           ## 이번 바퀴 남은 초 ("장거리 배송 중 · 남은 시간")
## 장거리 속도 옵션: route_id == "long" 일 때만 속도 %에 더함. 경험치는 routes[id].xp_per_parcel (없으면 지금 규칙)

## Setting: 부품 "turbo". Setting.unlocked(b, state, i, "turbo") = 대리점 + 그 트럭 +10. unlock_stage·unlock_star 그대로 씀

## scripts/core/contract.gd (새)
static func count(state: GameState) -> int                       ## 맺은 계약 수 0~3
static func next_reputation(b, state: GameState) -> int          ## 다음 계약 평판 기준 (다 맺었으면 -1)
static func hourly(b, state: GameState) -> float                 ## 계약 시간당 수입 합 (협상 반영, 세금 떼기 전)
static func hourly_of(b, state: GameState, k: int) -> float      ## k번째 계약
static func tick(state: GameState, b, dt: float) -> void         ## 평판 확인 → 체결(이벤트 { "type": "contract", "index": k, "hourly": n }) + 돈 쌓기
## GameState: contracts: Array (맺을 때 정해진 시간당 금액들), contract_carry: float (소수 이월), today_contract: int
## Company.today(state) 에 "contract": int 추가. Trip.apply_offline 결과에 "contract": int (세금 뗀 내 돈에 포함, "tax"에도 포함)
## Company.hourly_net(b, state) 에 계약 수입(세금 뗀 값) 포함 ("약 N분 뒤" 계산용). Company.hourly_sales 는 트럭만
## Quest: kind "long_laps"(장거리 바퀴 수 ≥ 1), "part_rolled" turbo, "contracts"(계약 수)
## Save: 형식 12
```

- 화면이 쓰는 계산은 위 함수만. 더 필요하면 계산 담당이 만들고 보고에 적는다

## 화면

| 곳 | 바뀌는 것 |
|---|---|
| 사무실 [트럭] 칸 | 트럭마다 [시내] [장거리] 스위치. 장거리가 잠겨 있으면 "+10부터" 안내. 스위치 옆에 두 노선의 시간당 번 돈 (`hourly_income_on`). 바꾸면 "다음 바퀴부터" 한 줄 |
| 튜닝숍 세팅 칸 | 네 번째 부품 터보 (잠금 안내: "대리점 + 엔진 +10"). 장거리 속도 옵션 설명 "장거리 노선에서만" |
| 띠·큰 화면 동네 | 장거리 바퀴인 트럭은 물류센터에서 **화면 밖으로 나갔다가** 바퀴가 끝날 때 돌아옴. 나가 있는 동안 구석에 "장거리 배송 중 · N분 N초" (트럭이 여러 대면 한 줄에 대수와 가장 빨리 돌아오는 시간). "+돈"은 계산 배송에 맞춰 화면 가장자리(나간 쪽)에 뜸. 띠에서 새로 그리는 것은 `visible_rects()`에 |
| 사무실 [장부] 칸 | "기업 계약" 줄 (오늘 계약 수입), 계약 N / 3, 다음 계약까지 평판 N |
| 알림 | 계약 체결 "기업 계약 체결! 시간당 +N", 장거리 열림 |
| 돌아왔을 때 요약 | 계약 수입 줄 |
| 글 | ko·en 둘 다 |

- 확인 스크립트: `tests/check_v7b.gd` (새). 완료 기준마다 결과 줄

## 시뮬 (`tools/tune_sim.py`)

`_reports/balance_v7b.md` + `_reports/v7b_proposal.diff` (json에는 안 넣음). 판정 = 창업 자금을 안 모으는 유저 30일 (+18 / +20은 그대로여야 함).

1. 장거리 단가 배수: 세팅 없는 트럭에서 시내와 시간당 수입이 비슷하거나 조금 높게 (+10 ~ +25 단계별 표). 이동 속도 3줄·터보 장거리 속도 3줄이면 장거리가 뚜렷이 이기고, 상하차 최대·적재량 세팅이면 시내가 이기는가 (노선 고르는 이유)
2. 터보 "장거리 속도" 한 줄 가치 (이동 속도 한 줄 = 1, 장거리에서): 전용 약 1.3
3. 계약 평판 기준: 노하우 안 찍은 가볍게 유저가 만렙 뒤 1 / 3 / 6주쯤 → 숫자 제안. 열심히 유저는 언제 닿는가
4. 계약 금액 5 / 7 / 10%가 창업 유저 수입·1위 시점(라이벌)에 주는 영향 (순위 매출에 안 넣으니 강화 속도로만)
5. 30일 판정이 그대로인지, 90일 1위 80%가 유지되는지

## 범위

- 넣음: 위 전부
- 안 넣음 (v8): 랩핑, 통계·도감, 업적, 설정, 스팀, 물류센터 업그레이드. 능력치 "영업력"(계약 개수 +1)은 출시 후

## 작업 순서와 담당

| 단계 | 담당 (가지) | 내용 | 완료 기준 |
|---|---|---|---|
| C1 | 계산 (`v7b-core`) | 장거리 노선·스위치·터보·장거리 속도, 저장 12 | `run_tests` 통과 (스위치 다음 바퀴부터, 잠금, 장거리 한 바퀴 시간·수입·경험치, 터보는 장거리에서만, 꺼둔 동안, 저장 왕복). 보고 `_reports/core_v7b_c1.md` |
| C2 | 계산 | 기업 계약 (contract.gd), 장부·오프라인·세금, 퀘스트 3개 | `run_tests` 통과. 보고 `core_v7b_c2.md` |
| C3 | 계산 | 시뮬 5항목 | `_reports/balance_v7b.md`, `v7b_proposal.diff` |
| U1 | 화면 (`v7b-ui`) | C1 합친 뒤: 노선 스위치, 터보 칸, 장거리 트럭 나갔다 돌아오기·남은 시간 | 기존 확인 전부 + `check_v7b.gd` 통과. 보고 `ui_v7b_u1.md` |
| U2 | 화면 | C2 합친 뒤: 장부 계약 줄, 알림, 요약 | 확인 전부 통과. 보고 `ui_v7b_u2.md` |
| 합치기 + QA | 조율자, core 페인 | | 확인 전부 통과, QA 보고 `_reports/qa_v7b.md` |

- 담당 파일: 계산 = `scripts/core/`, `data/`, `tests/test_*.gd`, `tools/`. 화면 = `scripts/ui/`, `scenes/`, `tests/check_*.gd`, 번역 파일

## 플레이 테스트 (사용자가 직접)

1. 어느 트럭을 장거리로 보낼지 고민했나? (예 / 아니오)
2. 터보를 돌릴 이유가 느껴졌나? (예 / 아니오)
3. 장거리 트럭이 화면에서 사라졌다 돌아오는 것이 허전하지 않았나? (예 / 아니오)
4. 기업 계약이 맺어졌을 때 반가웠나? (예 / 아니오)
