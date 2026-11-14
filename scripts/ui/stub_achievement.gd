## shortcut: v8a C2(scripts/core/achievement.gd) 전 임시 껍데기. 지시서 "코드 약속"의 Achievement 함수와 같은 이름·인자.
## C2를 합치면 화면 코드(main.gd, record_tab.gd)의 preload("res://scripts/ui/stub_achievement.gd")를
## preload("res://scripts/core/achievement.gd")로 바꾸고 이 파일을 지운다.
## 목록은 지시서 "옮길 숫자"의 achievements 그대로 (진짜는 balance.json). 진행·달성은 확인 스크립트가 넣는 가짜
extends RefCounted

const GameState = preload("res://scripts/core/game_state.gd")

const LIST := [
	{ "id": "first_parcel", "kind": "parcels", "target": 1 },
	{ "id": "parcels_10k", "kind": "parcels", "target": 10000 },
	{ "id": "parcels_1m", "kind": "parcels", "target": 1000000 },
	{ "id": "star_10", "kind": "best_star", "target": 10 },
	{ "id": "star_15", "kind": "best_star", "target": 15 },
	{ "id": "star_18", "kind": "best_star", "target": 18 },
	{ "id": "star_20", "kind": "best_star", "target": 20 },
	{ "id": "star_25", "kind": "best_star", "target": 25 },
	{ "id": "first_destroy", "kind": "destroys", "target": 1 },
	{ "id": "insured_save", "kind": "insured_saves", "target": 1 },
	{ "id": "setting_racing", "kind": "setting_grade", "target": 3 },
	{ "id": "setting_prototype", "kind": "setting_grade", "target": 4 },
	{ "id": "junk_triple", "kind": "junk_triples", "target": 1 },
	{ "id": "junk_book_15", "kind": "junk_book", "target": 15 },
	{ "id": "level_max", "kind": "level", "target": 50 },
	{ "id": "found_agency", "kind": "agency", "target": 1 },
	{ "id": "helpers_2", "kind": "helpers", "target": 2 },
	{ "id": "contracts_3", "kind": "contracts", "target": 3 },
	{ "id": "master_10", "kind": "master_visits", "target": 10 },
	{ "id": "rank_first", "kind": "rank_first", "target": 1 },
]

static var done := []     ## 달성한 업적 id (GameState.achievements_done 대신)
static var now := {}      ## 업적 id → 지금 진행 (없으면 0)


static func all(_b) -> Array:
	return LIST


static func is_done(_s: GameState, id: String) -> bool:
	return done.has(id)


static func progress(_b, _s: GameState, id: String) -> Array:
	for a: Dictionary in LIST:
		if a["id"] == id:
			return [now.get(id, 0), a["target"]]
	return [0, 0]


## 진짜는 새로 달성한 것마다 이벤트 + 랩핑 지급 (U2에서 연결)
static func check(_s: GameState, _b) -> void:
	pass
