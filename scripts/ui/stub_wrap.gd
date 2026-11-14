## shortcut: v8a C2(scripts/core/wrap.gd) 전 임시 껍데기. 지시서 "코드 약속"의 Wrap 함수와 같은 이름·인자.
## C2를 합치면 화면 코드(main.gd, wrap_tab.gd, record_tab.gd)의 preload("res://scripts/ui/stub_wrap.gd")를
## preload("res://scripts/core/wrap.gd")로 바꾸고, Wrap.worn(s, i)는 s.truck(i).wrap 으로 바꾼 뒤 이 파일을 지운다.
## 여기 값은 화면 시험용 가짜 (진짜는 balance.json wraps, GameState.wraps, TruckState.wrap)
extends RefCounted

const GameState = preload("res://scripts/core/game_state.gd")

const IDS := ["stripe", "flame", "gold18", "bandage"]
const FAKE_PRICES := { "stripe": 1000, "flame": 5000 }
const REWARDS := { "gold18": "star_18", "bandage": "first_destroy" }

static var owned_ids := []   ## 가진 랩핑 (GameState.wraps 대신)
static var worn_by := {}     ## 트럭 번호 → 입힌 랩핑 (TruckState.wrap 대신)


static func ids(_b) -> Array:
	return IDS


static func owned(_s: GameState, id: String) -> bool:
	return owned_ids.has(id)


static func price(_b, id: String) -> int:
	return FAKE_PRICES.get(id, -1)


static func reward_of(_b, id: String) -> String:
	return REWARDS.get(id, "")


static func can_buy(b, s: GameState, id: String) -> bool:
	return price(b, id) > 0 and not owned(s, id) and s.money >= price(b, id)


static func buy(b, s: GameState, id: String) -> bool:
	if not can_buy(b, s, id):
		return false
	s.money -= price(b, id)
	owned_ids.append(id)
	return true


static func wear(s: GameState, i: int, id: String) -> bool:
	if id != "" and not owned(s, id):
		return false
	worn_by[i] = id
	return true


## 약속에서는 TruckState.wrap (C2 뒤 s.truck(i).wrap)
static func worn(_s: GameState, i: int) -> String:
	return worn_by.get(i, "")
