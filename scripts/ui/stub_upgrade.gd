## shortcut: v8a C1(scripts/core/upgrade.gd) 전 임시 껍데기. 지시서 "코드 약속"의 Upgrade 함수와 같은 이름·인자.
## C1을 합치면 화면 코드(main.gd, driver_tab.gd)의 preload("res://scripts/ui/stub_upgrade.gd")를
## preload("res://scripts/core/upgrade.gd")로 바꾸고 이 파일을 지운다. 확인 스크립트(check_v8a.gd)가 아래 값을 넣어 화면 길을 시험한다.
## 여기 값은 화면 시험용 가짜 (가격·효과 규칙이 아님. 진짜는 balance.json depot_upgrades)
extends RefCounted

const Company = preload("res://scripts/core/company.gd")
const GameState = preload("res://scripts/core/game_state.gd")

const IDS := ["zone", "sort", "box"]
const FAKE_PRICE := 1000            ## 가짜 값: 다음 레벨 × 이것
const FAKE_PER_LEVEL := { "zone": 0.02, "sort": 0.06, "box": 1.0 }

static var on := true      ## json에 depot_upgrades 묶음이 있나 (확인 스크립트가 끔)
static var levels := {}    ## id → 레벨


static func enabled(_b) -> bool:
	return on


static func level(_s: GameState, id: String) -> int:
	return levels.get(id, 0)


static func max_level(_b, _id: String) -> int:
	return 5


static func price(b, s: GameState, id: String) -> int:
	var lv := level(s, id)
	return -1 if lv >= max_level(b, id) else (lv + 1) * FAKE_PRICE


static func can_buy(b, s: GameState, id: String) -> bool:
	var p := price(b, s, id)
	return Company.stage(s) == GameState.SOLO and p > 0 and s.money >= p


static func buy(b, s: GameState, id: String) -> bool:
	if not can_buy(b, s, id):
		return false
	s.money -= price(b, s, id)
	levels[id] = level(s, id) + 1
	return true


static func value(b, s: GameState, id: String) -> float:
	return value_at(b, id, level(s, id))


## 약속에 없음 (질문): 그 레벨의 효과. "지금 효과 → 다음 효과"의 다음 효과에 씀 (Depot.value_at 처럼)
static func value_at(_b, id: String, lv: int) -> float:
	return FAKE_PER_LEVEL[id] * lv
