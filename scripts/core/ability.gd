## 기사 능력치 (v5b): 상하차 속도·친절·협상·노하우·정비 지식에 포인트를 찍고 초기화한다.
## 화면 없이 돌아가는 계산 코드. (scripts/core 규칙) 굴리기 없음.
## 포인트 = GameState.ability_points (받은 합, 찍어도 안 줄어듦). 찍은 것은 GameState.abilities { id: 포인트 }.
## 효과를 쓰는 곳은 trip.gd (내 트럭 = 트럭 0에만): 상하차 → 정차 시간, 협상 → 단가, 친절 → 팁 확률,
## 노하우 → 꺼둔 동안 경험치, 정비 지식 → 스페어 드랍 확률. 능력치 이름은 번역 파일에 (여기서는 id만).
extends RefCounted

const Balance = preload("res://scripts/core/balance.gd")
const GameState = preload("res://scripts/core/game_state.gd")


## 능력치 id들 (json 순서. ["unload", "kind", "nego", "knowhow", "mech"])
static func ids(b: Balance) -> Array[String]:
	return b.ability_ids.duplicate()


## 그 능력치에 찍은 포인트 (안 찍었으면 0)
static func points(state: GameState, id: String) -> int:
	return int(state.abilities.get(id, 0))


static func max_points(b: Balance, id: String) -> int:
	return b.abilities[id]["max_points"]


## 지금 효과 = 포인트 × per_point (예: 협상 7 → 0.07). 모르는 id면 0
static func value(b: Balance, state: GameState, id: String) -> float:
	if not b.abilities.has(id):
		return 0.0
	return points(state, id) * b.abilities[id]["per_point"]


## 남은 포인트 = 받은 포인트 − 찍은 합
static func points_left(state: GameState) -> int:
	var used := 0
	for id in state.abilities:
		used += int(state.abilities[id])
	return state.ability_points - used


## 1포인트 더 찍을 수 있나: 아는 능력치, 최대 아님, 남은 포인트 있음
static func can_add(b: Balance, state: GameState, id: String) -> bool:
	return b.abilities.has(id) and points(state, id) < max_points(b, id) and points_left(state) > 0


## 1포인트 찍음. 못 찍으면 아무것도 안 하고 false
static func add(b: Balance, state: GameState, id: String) -> bool:
	if not can_add(b, state, id):
		return false
	state.abilities[id] = points(state, id) + 1
	return true


## 전부 0 (포인트는 그대로라 전부 돌려받음). 무료, 횟수 제한 없음
static func reset(state: GameState) -> void:
	state.abilities.clear()
