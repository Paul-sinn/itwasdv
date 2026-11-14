## 랩핑 (v8a): 차체 색·무늬만, 성능 없음. 구매용(json price, 게임 돈)과 보상용(json achievement, 업적 달성 때 Achievement.check가 줌).
## 화면 없이 돌아가는 계산 코드. (scripts/core 규칙) 굴리기 없음. 가진 랩핑을 트럭마다 골라 입힘 (기본 = "" 랩핑 없음)
extends RefCounted

const Balance = preload("res://scripts/core/balance.gd")
const GameState = preload("res://scripts/core/game_state.gd")


## 랩핑 id들 (json 순서)
static func ids(b) -> Array:
	return b.wraps.map(func(w): return w["id"])


static func owned(state: GameState, id: String) -> bool:
	return state.wraps.has(id)


## 구매용이면 값, 보상용·모르는 id면 -1
static func price(b, id: String) -> int:
	return _find(b, id).get("price", -1)


## 보상용이면 업적 id, 아니면 ""
static func reward_of(b, id: String) -> String:
	return _find(b, id).get("achievement", "")


## 구매용 + 안 가짐 + 돈
static func can_buy(b, state: GameState, id: String) -> bool:
	var p := price(b, id)
	return p >= 0 and not owned(state, id) and state.money >= p


## 돈을 내고 가짐. 못 사면 아무것도 안 하고 false
static func buy(b, state: GameState, id: String) -> bool:
	if not can_buy(b, state, id):
		return false
	state.money -= price(b, id)
	state.wraps.append(id)
	return true


## 트럭 i에 입힘 ("" = 벗김). 안 가진 랩핑이거나 없는 트럭이면 false (안 바꿈)
static func wear(state: GameState, i: int, id: String) -> bool:
	if i < 0 or i >= state.trucks.size() or (id != "" and not owned(state, id)):
		return false
	state.truck(i).wrap = id
	return true


## 업적 id를 보상으로 주는 랩핑 id, 없으면 ""
static func for_achievement(b, achievement_id: String) -> String:
	for w in b.wraps:
		if w["achievement"] == achievement_id:
			return w["id"]
	return ""


static func _find(b, id: String) -> Dictionary:
	for w in b.wraps:
		if w["id"] == id:
			return w
	return {}
