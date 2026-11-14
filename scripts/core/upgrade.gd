## 물류센터 업그레이드 (v8a): 정해진 값만 오르는 단순 구매 3개 × Lv0 → Lv(prices 길이).
##   zone(배송 구역 확장) = 단가 × (1 + 값), sort(분류 속도) = 싣는 시간 × (1 − 값), box(기본 적재함) = 기본 적재량 + 값(건)
## 화면 없이 돌아가는 계산 코드. (scripts/core 규칙) 굴리기 없음.
## 개인 기사일 때만 살 수 있고, 산 효과는 대리점 뒤에도 모든 트럭에 (Trip._unit·_load·cargo가 value를 읽음. 꺼둔 동안도 그 식으로)
## json depot_upgrades 묶음이 없으면 꺼짐: 효과 0, 못 삼, max_level 0 (화면도 줄을 숨김). 일정이 밀리면 이 묶음부터 지운다
extends RefCounted

const Balance = preload("res://scripts/core/balance.gd")
const GameState = preload("res://scripts/core/game_state.gd")

const IDS := Balance.UPGRADE_IDS   ## ["zone", "sort", "box"]


## json에 depot_upgrades 묶음이 있나
static func enabled(b) -> bool:
	return not b.depot_upgrades.is_empty()


## 지금 레벨 0~max_level
static func level(state: GameState, id: String) -> int:
	return state.depot_upgrades.get(id, 0)


## 마지막 레벨 (= 가격 수). 꺼졌으면 0
static func max_level(b, id: String) -> int:
	return b.depot_upgrades[id]["prices"].size() if enabled(b) else 0


## 다음 레벨 값. 다 샀거나 꺼졌으면 -1
static func price(b, state: GameState, id: String) -> int:
	var lv := level(state, id)
	return b.depot_upgrades[id]["prices"][lv] if lv < max_level(b, id) else -1


## 개인 기사 + 레벨 남음 + 돈
static func can_buy(b, state: GameState, id: String) -> bool:
	var p := price(b, state, id)
	return state.company_stage == GameState.SOLO and p >= 0 and state.money >= p


## 돈을 내고 레벨 +1. 못 사면 아무것도 안 하고 false
static func buy(b, state: GameState, id: String) -> bool:
	if not can_buy(b, state, id):
		return false
	state.money -= price(b, state, id)
	state.depot_upgrades[id] = level(state, id) + 1
	return true


## 지금 효과 = per_level × 레벨 (zone 0.04 = 단가 +4%, sort 0.12 = 싣는 시간 −12%, box 2.0 = +2건). 꺼졌으면 0
static func value(b, state: GameState, id: String) -> float:
	return value_at(b, id, level(state, id))


## 레벨 lv일 때 효과 (화면 "지금 → 다음" 표시용). 꺼졌으면 0
static func value_at(b, id: String, lv: int) -> float:
	return b.depot_upgrades[id]["per_level"] * lv if enabled(b) else 0.0
