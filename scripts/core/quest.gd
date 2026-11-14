## 퀘스트 ("다음 할 일"): balance.json quests 목록을 순서대로 하나씩. 조건이 차면 자동으로 끝나고 보상(경험치 + 돈).
## 화면 없이 돌아가는 계산 코드. (scripts/core 규칙) 굴리기 없음. 이름·설명은 번역 파일(QUEST_<ID 대문자>), 여기는 id만.
## 조건 = 종류(kind)별 "지금 값 ≥ target". 이미 넘긴 퀘스트는 차례가 오면 check 한 번에 하나씩 끝난다 (알림이 하나씩 뜨게)
extends RefCounted

const Balance = preload("res://scripts/core/balance.gd")
const Driver = preload("res://scripts/core/driver.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const TruckState = preload("res://scripts/core/truck_state.gd")


static func count(b: Balance) -> int:
	return b.quests.size()


## 지금 차례 퀘스트의 묶음 { id, kind, target, part, xp, money }. 다 끝났으면 {}
static func current(b: Balance, state: GameState) -> Dictionary:
	if state.quest_index >= count(b):
		return {}
	return b.quests[state.quest_index]


## [지금 값, target]. 다 끝났으면 [0, 0]. 지금 값은 target을 넘을 수 있다 (자르지 않음)
static func progress(b: Balance, state: GameState) -> Array:
	var q := current(b, state)
	if q.is_empty():
		return [0, 0]
	return [_value(state, q), q["target"]]


## 지금 차례 퀘스트가 찼으면 보상(돈 + 경험치)을 주고 다음으로 (한 번에 하나). 끝냈으면 true
static func check(state: GameState, b: Balance) -> bool:
	var q := current(b, state)
	if q.is_empty() or _value(state, q) < q["target"]:
		return false
	state.quest_index += 1
	state.money += q["money"]
	state.add_event({ "type": "quest_done", "id": q["id"], "xp": q["xp"], "money": q["money"] })
	Driver.add_xp(state, b, q["xp"])
	return true


## 퀘스트 종류별 지금 값
static func _value(state: GameState, q: Dictionary) -> int:
	match q["kind"]:
		"parcels":
			return state.parcels_total
		"star":
			var top := 0
			for t: TruckState in state.trucks:
				top = maxi(top, t.star)
			return top
		"setting_rolls":
			return state.setting_rolls
		"setting_grade":   # 지금 쓰는 등급 (고르기 전 새 상태는 안 셈)
			var top := 0
			for t: TruckState in state.trucks:
				for p in t.settings.values():
					top = maxi(top, p["grade"])
			return top
		"part_rolled":
			return 1 if state.parts_rolled.has(q["part"]) else 0
		"spares_bought":
			return state.spares_bought
		"warehouse":
			return state.warehouse_level
		"night":
			return state.night_level
		"level":
			return state.driver_level
		"agency":   # 창업했나
			return 1 if state.company_stage >= GameState.AGENCY else 0
		"helpers":   # 보조 트럭 수
			return state.trucks.size() - 1
	return 0   # balance.gd가 모르는 kind를 막으므로 여기 안 옴
