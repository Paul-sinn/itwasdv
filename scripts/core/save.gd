## 저장 파일 읽고 쓰기 (기본 user://save.json). 화면 없이 돌아가는 코드.
##
## 파일 모양 (JSON, 손으로 고쳐도 됨):
##   saved_at_utc  저장한 시각. 세계 표준시(UTC) "YYYY-MM-DDTHH:MM:SS"
##                 → 꺼둔 동안 수익 확인할 때 이걸 3시간 전 / 20시간 전 / 미래로 고친다
##   money, star, broken, star_before_break, success_count, fail_count, destroy_count
##   (형식 2부터) tune { 부위 id: 등급 0~3 }, tune_press_count, tune_up_count, jackpot_count
## 형식 1 파일(튜닝 전)도 읽는다: 튜닝 칸이 없으면 전부 일반(0)·통계 0.
## tune 안의 모르는 부위 id는 버리고, 등급은 0~최고 등급으로 자른다.
extends RefCounted

const Balance = preload("res://scripts/core/balance.gd")
const GameState = preload("res://scripts/core/game_state.gd")

const DEFAULT_PATH := "user://save.json"
const FORMAT_VERSION := 2   ## 1: v0·v1 / 2: 튜닝(v2) 추가

enum Status { OK, NONE, BROKEN }   ## 읽음 / 저장 파일 없음(새 게임) / 깨짐(새 게임)


## 상태 → 저장할 묶음
static func to_dict(s: GameState, saved_at_unix: int) -> Dictionary:
	return {
		"version": FORMAT_VERSION,
		"saved_at_utc": Time.get_datetime_string_from_unix_time(saved_at_unix),
		"money": s.money,
		"star": s.star,
		"broken": s.broken,
		"star_before_break": s.star_before_break,
		"success_count": s.success_count,
		"fail_count": s.fail_count,
		"destroy_count": s.destroy_count,
		"tune": _tune_to_dict(s),
		"tune_press_count": s.tune_press_count,
		"tune_up_count": s.tune_up_count,
		"jackpot_count": s.jackpot_count,
	}


## 부위 id → 등급. 7부위 전부 적는다 (손으로 고치기 쉽게)
static func _tune_to_dict(s: GameState) -> Dictionary:
	var t := {}
	for part in Balance.TUNE_EFFECT_KEYS:
		t[part] = s.grade(part)
	return t


## 저장 묶음 → 상태. 결과: { status, state, saved_at, error }
## 빠진 칸, 틀린 모양, 말이 안 되는 값(음수 돈, 범위 밖 강수 등)이 있으면 BROKEN.
static func from_dict(d, b: Balance) -> Dictionary:
	if typeof(d) != TYPE_DICTIONARY:
		return _broken("맨 바깥이 { } 묶음이 아님")

	var when = d.get("saved_at_utc")
	if typeof(when) != TYPE_STRING:
		return _broken("saved_at_utc 가 없음")
	var saved_at := _parse_utc(when)
	if saved_at < 0:
		return _broken("saved_at_utc 모양이 틀림: %s (예: 2026-11-10T09:30:00)" % when)

	var s := GameState.new()
	var money = d.get("money")
	if not _is_number(money) or not is_finite(float(money)) or float(money) < 0.0:
		return _broken("money 가 0 이상의 숫자가 아님: %s" % [money])
	s.money = float(money)

	var star = _whole(d.get("star"), 0, b.max_star)
	if star == null:
		return _broken("star 가 0~%d 정수가 아님: %s" % [b.max_star, d.get("star")])
	s.star = star

	if typeof(d.get("broken")) != TYPE_BOOL:
		return _broken("broken 이 true/false 가 아님: %s" % [d.get("broken")])
	s.broken = d["broken"]

	var before = _whole(d.get("star_before_break"), 0, b.max_star)
	if before == null:
		return _broken("star_before_break 가 0~%d 정수가 아님: %s" % [b.max_star, d.get("star_before_break")])
	s.star_before_break = before

	for key in ["success_count", "fail_count", "destroy_count"]:
		var n = _whole(d.get(key), 0, 1 << 52)
		if n == null:
			return _broken("%s 가 0 이상 정수가 아님: %s" % [key, d.get(key)])
		s.set(key, n)

	# --- 튜닝 (형식 2). 칸이 없으면(형식 1) 전부 일반·0 ---
	for key in ["tune_press_count", "tune_up_count", "jackpot_count"]:
		if not d.has(key):
			continue
		var n = _whole(d[key], 0, 1 << 52)
		if n == null:
			return _broken("%s 가 0 이상 정수가 아님: %s" % [key, d[key]])
		s.set(key, n)
	if d.has("tune"):
		var t = d["tune"]
		if typeof(t) != TYPE_DICTIONARY:
			return _broken("tune 이 { } 묶음이 아님: %s" % [t])
		var top := b.tune_grades.size() - 1
		for part in t:
			if not Balance.TUNE_EFFECT_KEYS.has(part):
				continue   # 모르는 부위는 버림
			var g = t[part]
			if not _is_number(g) or not is_finite(float(g)):
				return _broken("tune.%s 등급이 숫자가 아님: %s" % [part, g])
			s.tune[part] = int(clampf(floorf(float(g)), 0.0, top))   # 등급은 0~최고로 자름

	return { "status": Status.OK, "state": s, "saved_at": saved_at, "error": "" }


## 파일에 쓴다. 다 쓴 다음에 바꿔 끼워서, 쓰다가 꺼져도 원래 파일이 깨지지 않게.
static func write_file(path: String, s: GameState, saved_at_unix: int) -> Error:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(to_dict(s, saved_at_unix), "  ", false, true))
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(tmp, path)


## 파일에서 읽는다. 결과: { status, state, saved_at, error }
## 깨진 파일은 path + ".broken" 으로 옮겨 둔다 (원인 볼 수 있게).
static func read_file(path: String, b: Balance) -> Dictionary:
	if not FileAccess.file_exists(path):
		# 바꿔 끼우는 순간 꺼졌으면 .tmp 만 남아 있을 수 있음
		if FileAccess.file_exists(path + ".tmp"):
			DirAccess.rename_absolute(path + ".tmp", path)
		else:
			return { "status": Status.NONE, "state": null, "saved_at": 0, "error": "" }
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return _keep_broken(path, _broken("파일을 열 수 없음 (오류 %d)" % FileAccess.get_open_error()))
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return _keep_broken(path, _broken("JSON 형식이 깨짐 (%d번째 줄: %s)" % [json.get_error_line() + 1, json.get_error_message()]))
	var result := from_dict(json.data, b)
	if result["status"] == Status.BROKEN:
		return _keep_broken(path, result)
	return result


static func delete_file(path: String) -> void:
	for p in [path, path + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


static func _keep_broken(path: String, result: Dictionary) -> Dictionary:
	var keep := path + ".broken"
	if FileAccess.file_exists(keep):
		DirAccess.remove_absolute(keep)
	DirAccess.rename_absolute(path, keep)
	return result


static func _broken(why: String) -> Dictionary:
	return { "status": Status.BROKEN, "state": null, "saved_at": 0, "error": why }


## "YYYY-MM-DDTHH:MM:SS" → 유닉스 시각(초). 틀린 모양이면 -1.
## (Godot 함수에 틀린 글자를 바로 넣으면 빨간 오류를 찍어서, 모양부터 본다)
static func _parse_utc(text: String) -> int:
	var re := RegEx.create_from_string("^(\\d{4})-(\\d{2})-(\\d{2})T(\\d{2}):(\\d{2}):(\\d{2})$")
	var m := re.search(text)
	if m == null:
		return -1
	var year := int(m.get_string(1))
	var month := int(m.get_string(2))
	var day := int(m.get_string(3))
	if month < 1 or month > 12 or int(m.get_string(4)) > 23 \
			or int(m.get_string(5)) > 59 or int(m.get_string(6)) > 59:
		return -1
	var leap := (year % 4 == 0 and year % 100 != 0) or year % 400 == 0
	var days_in_month := [31, 29 if leap else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	if day < 1 or day > days_in_month[month - 1]:
		return -1
	return Time.get_unix_time_from_datetime_string(text)


static func _is_number(v) -> bool:
	return typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT


## lo~hi 사이 정수면 int, 아니면 null
static func _whole(v, lo: int, hi: int):
	if not _is_number(v):
		return null
	var x := float(v)
	if not is_finite(x) or x != floorf(x) or x < lo or x > hi:
		return null
	return int(x)
