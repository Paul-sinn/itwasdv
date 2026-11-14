## 통계와 잡옵 도감 (v8a). 화면 없이 돌아가는 계산 코드. (scripts/core 규칙) 굴리기 없음.
## 이미 다른 칸에 있는 것(배송 수, 트럭 강화 결과 수, 세팅 돌린 수)은 그 칸을 읽고, 없는 것만 GameState.stats에 센다:
##   money_earned 번 돈 (배송·팁·꺼둔 동안·기업 계약, 직원 몫·세금 떼기 전. Trip._earn·Contract._earn)
##   seconds_on 켜 둔 초 (tick, 화면이 프레임마다), best_star 최고 강화 단계 (Enhance 성공), insured_saves 보험이 막은 퍼짐 (Enhance),
##   tips 받은 팁 수 (Trip, 켜 둔 동안만), master_visits 명장 방문 수 (Master 방문 알림)
## 잡옵 도감: 세팅을 돌려 결과(pending)에 잡옵 줄이 나온 순간 그 (옵션, 결과 등급) 칸의 본 횟수 +줄 수 (고르지 않아도). Setting.try_roll이 부름.
##   한 결과에 같은 잡옵 3줄 → 그 칸에 별 (junk_triples)
extends RefCounted

const Balance = preload("res://scripts/core/balance.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const TruckState = preload("res://scripts/core/truck_state.gd")

## GameState.stats에 두는 칸 (저장도 이것만). seconds_on만 소수
const COUNTERS := ["money_earned", "seconds_on", "best_star", "insured_saves", "tips", "master_visits"]
const TRIPLE_LINES := 3


## 통계 12개 (화면 [기록] 칸). seconds_on만 소수, 나머지 정수
##   best_star = 센 값과 지금 트럭 단계 중 큰 것 (옛 저장·치트로 단계를 바꿔도 맞게)
static func get_all(state: GameState) -> Dictionary:
	var succ := 0
	var fails := 0
	var destroys := 0
	for t: TruckState in state.trucks:
		succ += t.success_count
		fails += t.fail_count
		destroys += t.destroy_count
	return { "parcels": state.parcels_total, "money_earned": _count(state, "money_earned"), "seconds_on": float(state.stats.get("seconds_on", 0.0)),
			"best_star": best_star(state), "tries": succ + fails + destroys, "successes": succ, "fails": fails, "destroys": destroys,
			"insured_saves": _count(state, "insured_saves"), "setting_rolls": state.setting_rolls, "tips": _count(state, "tips"),
			"master_visits": _count(state, "master_visits") }


## 켜 둔 시간 dt초를 더함. 화면이 프레임마다
static func tick(state: GameState, dt: float) -> void:
	if dt > 0.0:
		state.stats["seconds_on"] = float(state.stats.get("seconds_on", 0.0)) + dt


## 최고 강화 단계 (센 값과 지금 트럭 단계 중 큰 것)
static func best_star(state: GameState) -> int:
	var top := _count(state, "best_star")
	for t: TruckState in state.trucks:
		top = maxi(top, t.star)
	return top


## 정수 통계 key에 n을 더함 (계산 코드가 부름)
static func add(state: GameState, key: String, n: int) -> void:
	state.stats[key] = _count(state, key) + n


## 강화로 star에 닿음 (Enhance 성공)
static func note_star(state: GameState, star: int) -> void:
	state.stats["best_star"] = maxi(_count(state, "best_star"), star)


## 세팅 결과 하나 (등급 grade, 줄 lines)를 도감에 (Setting.try_roll)
static func see_lines(b: Balance, state: GameState, grade: int, lines: Array) -> void:
	for op in lines:
		if b.setting_options[op]["kind"] != "junk":
			continue
		var key := cell(op, grade)
		state.junk_seen[key] = int(state.junk_seen.get(key, 0)) + 1
		if lines.count(op) >= TRIPLE_LINES and not state.junk_triples.has(key):
			state.junk_triples.append(key)


## 잡옵 도감 25칸 (json 옵션 순서의 잡옵 × 등급 0~4): [{ "option": id, "grade": int, "seen": int (0 = 안 본 칸), "triple": bool }]
static func junk_book(b: Balance, state: GameState) -> Array:
	var out := []
	for op in b.setting_options:
		if b.setting_options[op]["kind"] != "junk":
			continue
		for g in Balance.SETTING_GRADES:
			var key := cell(op, g)
			out.append({ "option": op, "grade": g, "seen": int(state.junk_seen.get(key, 0)), "triple": state.junk_triples.has(key) })
	return out


## 채운 칸 수 (한 번이라도 본 칸)
static func junk_book_count(state: GameState) -> int:
	return state.junk_seen.size()


## 도감 칸 이름 "옵션 id/등급" (junk_seen·junk_triples 키)
static func cell(option: String, grade: int) -> String:
	return "%s/%d" % [option, grade]


static func _count(state: GameState, key: String) -> int:
	return int(state.stats.get(key, 0))
