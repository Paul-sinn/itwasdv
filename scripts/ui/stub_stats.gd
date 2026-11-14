## shortcut: v8a C2(scripts/core/stats.gd) 전 임시 껍데기. 지시서 "코드 약속"의 Stats 함수와 같은 이름·인자.
## C2를 합치면 화면 코드(main.gd, record_tab.gd)의 preload("res://scripts/ui/stub_stats.gd")를
## preload("res://scripts/core/stats.gd")로 바꾸고 이 파일을 지운다.
## 여기 값은 화면 시험용 가짜 (진짜는 GameState.stats, junk_seen)
extends RefCounted

const GameState = preload("res://scripts/core/game_state.gd")
const Setting = preload("res://scripts/core/setting.gd")

const KEYS := ["parcels", "money_earned", "seconds_on", "best_star", "tries", "successes", "fails", "destroys",
		"insured_saves", "setting_rolls", "tips", "master_visits"]

static var values := {}    ## 통계 키 → 값 (없으면 0)
static var seen := {}      ## "잡옵 id:등급" → 본 횟수
static var triples := {}   ## "잡옵 id:등급" → true (3줄 나옴)


static func get_all(_s: GameState) -> Dictionary:
	var out := {}
	for k: String in KEYS:
		out[k] = values.get(k, 0)
	return out


## 25칸: 잡옵(balance setting_options 중 kind "junk", json 순서) × 등급
static func junk_book(b, _s: GameState) -> Array:
	var out := []
	for id: String in b.setting_options:
		if Setting.option_kind(b, id) != "junk":
			continue
		for g in Setting.max_grade(b) + 1:
			var key := "%s:%d" % [id, g]
			out.append({ "option": id, "grade": g, "seen": seen.get(key, 0), "triple": triples.has(key) })
	return out


static func junk_book_count(_s: GameState) -> int:
	return seen.size()


static func tick(_s: GameState, dt: float) -> void:
	values["seconds_on"] = values.get("seconds_on", 0.0) + dt
