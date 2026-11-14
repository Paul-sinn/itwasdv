## 업적 (v8a): json achievements 20개, 한 번씩. 조건 = 종류(kind)별 "지금 값 ≥ target". 보상은 랩핑 2개만 (wraps의 achievement).
## 화면 없이 돌아가는 계산 코드. (scripts/core 규칙) 굴리기 없음. 이름·설명은 번역 파일, 여기는 id만.
## check는 화면이 프레임마다 부름 (이미 넘긴 업적은 다음 check에서 한꺼번에 달성: 옛 저장도 첫 프레임에)
extends RefCounted

const Balance = preload("res://scripts/core/balance.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const Quest = preload("res://scripts/core/quest.gd")
const Stats = preload("res://scripts/core/stats.gd")
const Wrap = preload("res://scripts/core/wrap.gd")


## 업적 목록 (json 순서) [{ "id", "kind", "target" }]
static func all(b) -> Array:
	return b.achievements


static func is_done(state: GameState, id: String) -> bool:
	return state.achievements_done.has(id)


## [지금 값, 목표]. 지금 값은 목표를 넘을 수 있다 (자르지 않음). 모르는 id면 [0, 0]
static func progress(b, state: GameState, id: String) -> Array:
	for a in b.achievements:
		if a["id"] == id:
			return [_value(state, a["kind"]), a["target"]]
	return [0, 0]


## 새로 달성한 업적마다: achievements_done에 넣고, 보상 랩핑이 있으면 가진 랩핑에 (이미 있으면 그대로),
## 알림 { "type": "achievement", "id": id, "wrap": 랩핑 id 또는 "" }. 화면이 프레임마다
static func check(state: GameState, b) -> void:
	for a in b.achievements:
		if is_done(state, a["id"]) or _value(state, a["kind"]) < a["target"]:
			continue
		state.achievements_done.append(a["id"])
		var wrap := Wrap.for_achievement(b, a["id"])
		if wrap != "" and not Wrap.owned(state, wrap):
			state.wraps.append(wrap)
		state.add_event({ "type": "achievement", "id": a["id"], "wrap": wrap })


## 업적 종류별 지금 값
static func _value(state: GameState, kind: String) -> int:
	match kind:
		"best_star":
			return Stats.best_star(state)
		"destroys":
			return Stats.get_all(state)["destroys"]
		"insured_saves", "master_visits":
			return int(state.stats.get(kind, 0))
		"junk_triples":
			return state.junk_triples.size()
		"junk_book":
			return Stats.junk_book_count(state)
		"rank_first":
			return 1 if state.rank_first_done else 0
	return Quest.value_of(state, { "kind": kind })   # parcels·setting_grade·level·agency·helpers·contracts는 퀘스트와 같은 값
