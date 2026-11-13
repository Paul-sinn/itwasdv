## 물류센터 업그레이드: 창고 확장(꺼둔 동안 쌓이는 시간), 야간 배송팀(꺼둔 동안 버는 비율).
## 화면 없이 돌아가는 계산 코드. (scripts/core 규칙) 굴리기 없음.
## kind = "warehouse"(창고 확장) 또는 "night"(야간 배송팀). 레벨은 1부터.
extends RefCounted

const Balance = preload("res://scripts/core/balance.gd")
const GameState = preload("res://scripts/core/game_state.gd")


## 꺼둔 동안 쌓이는 최대 시간 (지금 창고 레벨)
static func cap_hours(b: Balance, state: GameState) -> float:
	return value_at(b, "warehouse", state.warehouse_level)


## 꺼둔 동안 버는 비율 (지금 야간팀 레벨)
static func rate(b: Balance, state: GameState) -> float:
	return value_at(b, "night", state.night_level)


static func level(state: GameState, kind: String) -> int:
	return state.warehouse_level if kind == "warehouse" else state.night_level


## 표의 마지막 레벨 (4)
static func top_level(b: Balance, kind: String) -> int:
	return _values(b, kind).size()


## 지금 살 수 있는 최고 레벨. 창고는 대리점 전이라 warehouse_max_level_solo(3)까지
static func buyable_level(b: Balance, _state: GameState, kind: String) -> int:
	if kind == "warehouse":
		return mini(b.warehouse_max_level_solo, top_level(b, kind))
	return top_level(b, kind)


## 그 레벨의 시간(창고) 또는 비율(야간팀). 화면 표시용 ("4시간 → 6시간")
static func value_at(b: Balance, kind: String, lv: int) -> float:
	return _values(b, kind)[lv - 1]


## 다음 레벨 가격. 더 못 사면 0
static func price(b: Balance, state: GameState, kind: String) -> int:
	var lv := level(state, kind)
	if lv >= buyable_level(b, state, kind):
		return 0
	var prices := b.warehouse_prices if kind == "warehouse" else b.night_prices
	return prices[lv - 1]


static func can_upgrade(b: Balance, state: GameState, kind: String) -> bool:
	var p := price(b, state, kind)
	return p > 0 and state.money >= p


## 돈을 내고 레벨 +1. 못 사면 아무것도 안 하고 false
static func upgrade(b: Balance, state: GameState, kind: String) -> bool:
	if not can_upgrade(b, state, kind):
		return false
	state.money -= price(b, state, kind)
	if kind == "warehouse":
		state.warehouse_level += 1
	else:
		state.night_level += 1
	return true


static func _values(b: Balance, kind: String) -> PackedFloat64Array:
	return b.warehouse_hours if kind == "warehouse" else b.night_rates
